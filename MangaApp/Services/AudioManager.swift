import AVFoundation
import Combine

/// Manages microphone capture and audio playback for the Deepgram Voice Agent.
/// - Microphone: Captures PCM linear16, 16kHz, mono audio via AVAudioEngine
/// - Playback: Streams Deepgram TTS audio (linear16, 24kHz, mono) via AVAudioPlayerNode
final class AudioManager: ObservableObject {
    @Published var isMicActive = false
    @Published var micPermissionGranted = false
    @Published var audioLevel: Float = 0.0

    // MARK: - Audio Engine (Microphone)

    private let captureEngine = AVAudioEngine()
    private var isCaptureEngineRunning = false
    private var capturedChunkCount = 0

    /// Called whenever a chunk of mic audio is captured
    var onAudioCaptured: ((Data) -> Void)?

    // MARK: - Audio Playback

    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlaybackEngineRunning = false

    /// Playback format: linear16, 24kHz, mono (matches Deepgram TTS output)
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    // MARK: - Init

    init() {
        checkMicPermission()
    }

    // MARK: - Permission

    func checkMicPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            micPermissionGranted = true
        case .denied:
            micPermissionGranted = false
        case .undetermined:
            micPermissionGranted = false
        @unknown default:
            micPermissionGranted = false
        }
    }

    func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.micPermissionGranted = granted
                }
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Microphone Capture

    func startCapture() throws {
        guard !isCaptureEngineRunning else { return }

        try configureAudioSession()

        let inputNode = captureEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        capturedChunkCount = 0
        print("[AudioManager] Starting capture. Hardware format: \(hardwareFormat)")

        // Target format: PCM Int16, 16kHz, mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            throw AudioManagerError.formatError
        }
        print("[AudioManager] Target capture format: \(targetFormat)")

        // Install a converter if needed
        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw AudioManagerError.converterError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Update audio level for UI visualization
            self.updateAudioLevel(buffer: buffer)

            // Convert to target format
            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * (16000.0 / hardwareFormat.sampleRate)
            )

            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else {
                print("[AudioManager] Audio convert error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            // Convert PCM buffer to Data
            if let data = convertedBuffer.toData() {
                self.capturedChunkCount += 1
                if self.capturedChunkCount <= 10 || self.capturedChunkCount % 50 == 0 {
                    let metrics = data.pcm16Metrics()
                    print(
                        "[AudioManager] Captured chunk #\(self.capturedChunkCount): frames=\(convertedBuffer.frameLength), bytes=\(data.count), rms=\(metrics.rms), peak=\(metrics.peak)"
                    )
                }
                self.onAudioCaptured?(data)
            } else if self.capturedChunkCount < 10 {
                print("[AudioManager] Converted buffer produced no data")
            }
        }

        captureEngine.prepare()
        try captureEngine.start()
        isCaptureEngineRunning = true
        print("[AudioManager] Capture engine started")

        DispatchQueue.main.async {
            self.isMicActive = true
        }
    }

    func stopCapture() {
        guard isCaptureEngineRunning else { return }

        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        isCaptureEngineRunning = false
        print("[AudioManager] Capture engine stopped after \(capturedChunkCount) chunks")

        DispatchQueue.main.async {
            self.isMicActive = false
            self.audioLevel = 0.0
        }
    }

    // MARK: - Audio Playback

    func startPlaybackEngine() throws {
        guard !isPlaybackEngineRunning else { return }

        playbackEngine.attach(playerNode)

        // Connect player node with playback format
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)

        playbackEngine.prepare()
        try playbackEngine.start()
        playerNode.play()
        isPlaybackEngineRunning = true
    }

    /// Enqueue raw PCM audio data (linear16, 24kHz, mono) for playback
    func playAudioData(_ data: Data) {
        guard isPlaybackEngineRunning else { return }

        let sampleCount = data.count / 2 // 16-bit = 2 bytes per sample
        guard sampleCount > 0 else { return }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // Copy data into the PCM buffer
        data.withUnsafeBytes { rawBufferPointer in
            guard let srcPointer = rawBufferPointer.baseAddress else { return }
            if let channelData = buffer.int16ChannelData {
                memcpy(channelData[0], srcPointer, data.count)
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    func stopPlayback() {
        playerNode.stop()

        if isPlaybackEngineRunning {
            playbackEngine.stop()
            playbackEngine.detach(playerNode)
            isPlaybackEngineRunning = false
        }
    }

    // MARK: - Cleanup

    func stopAll() {
        stopCapture()
        stopPlayback()
        deactivateAudioSession()
    }

    // MARK: - Audio Level

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frames {
            sum += abs(channelData[i])
        }

        let avg = sum / Float(frames)
        let level = min(max(avg * 5.0, 0), 1.0) // Normalize to 0...1

        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
}

// MARK: - Errors

enum AudioManagerError: LocalizedError {
    case formatError
    case converterError

    var errorDescription: String? {
        switch self {
        case .formatError:
            return "Failed to create audio format"
        case .converterError:
            return "Failed to create audio converter"
        }
    }
}

// MARK: - AVAudioPCMBuffer Extension

extension AVAudioPCMBuffer {
    /// Convert PCM buffer to raw Data (for sending over WebSocket)
    func toData() -> Data? {
        guard frameLength > 0 else { return nil }

        if let audioBuffer = audioBufferList.pointee.mBuffers.mData,
           audioBufferList.pointee.mBuffers.mDataByteSize > 0 {
            return Data(
                bytes: audioBuffer,
                count: Int(audioBufferList.pointee.mBuffers.mDataByteSize)
            )
        }

        if let int16Data = int16ChannelData {
            let byteCount = Int(frameLength) * MemoryLayout<Int16>.size
            return Data(bytes: int16Data[0], count: byteCount)
        }

        // Fallback: convert float data to Int16
        if let floatData = floatChannelData {
            let frames = Int(frameLength)
            var int16Samples = [Int16](repeating: 0, count: frames)

            for i in 0..<frames {
                let sample = max(-1.0, min(1.0, floatData[0][i]))
                int16Samples[i] = Int16(sample * Float(Int16.max))
            }

            return Data(bytes: &int16Samples, count: frames * MemoryLayout<Int16>.size)
        }

        return nil
    }
}

private extension Data {
    func pcm16Metrics() -> (rms: Int, peak: Int) {
        guard count >= MemoryLayout<Int16>.size else { return (0, 0) }

        var sumSquares: Double = 0
        var peak = 0
        let sampleCount = count / MemoryLayout<Int16>.size

        withUnsafeBytes { rawBuffer in
            guard let samples = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }

            for index in 0..<sampleCount {
                let value = Int(samples[index])
                let magnitude = abs(value)
                peak = Swift.max(peak, magnitude)
                sumSquares += Double(value * value)
            }
        }

        let rms = Int(sqrt(sumSquares / Double(sampleCount)))
        return (rms, peak)
    }
}
