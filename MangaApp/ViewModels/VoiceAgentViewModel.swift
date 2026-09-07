import Foundation
import Combine

/// Represents a single message in the voice conversation
struct ConversationMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date

    enum Role {
        case user
        case agent
        case system
    }

    static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// ViewModel orchestrating the Voice Agent flow between UI, DeepgramService, and AudioManager
@MainActor
final class VoiceAgentViewModel: ObservableObject {

    // MARK: - Published State

    @Published var agentState: AgentState = .idle
    @Published var messages: [ConversationMessage] = []
    @Published var searchResults: [Manga] = []
    @Published var isMuted = false
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0

    enum AgentState: Equatable {
        case idle
        case connecting
        case listening
        case agentThinking
        case agentSpeaking
        case error(String)
    }

    // MARK: - Services

    private let deepgramService = DeepgramService()
    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Forward audio level from AudioManager
        audioManager.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$audioLevel)

        // Watch DeepgramService connection state
        deepgramService.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .disconnected:
                    if self.agentState != .idle {
                        self.agentState = .idle
                    }
                case .connecting:
                    self.agentState = .connecting
                case .connected:
                    // Will transition to .listening when SettingsApplied
                    break
                case .error(let msg):
                    self.agentState = .error(msg)
                    self.errorMessage = msg
                }
            }
            .store(in: &cancellables)

        // Setup DeepgramService callbacks
        deepgramService.onReady = { [weak self] in
            Task { @MainActor in
                self?.agentState = .listening
                self?.addSystemMessage("MangaBot is ready! Start talking to find manga.")
                do {
                    try self?.audioManager.startCapture()
                } catch {
                    print("[VoiceAgent] Failed to start capture: \(error.localizedDescription)")
                    self?.errorMessage = "Failed to start microphone: \(error.localizedDescription)"
                    self?.agentState = .error(error.localizedDescription)
                }
            }
        }

        deepgramService.onUserTranscript = { [weak self] text in
            Task { @MainActor in
                self?.addMessage(role: .user, text: text)
                self?.agentState = .agentThinking
            }
        }

        deepgramService.onAgentText = { [weak self] text in
            Task { @MainActor in
                self?.addMessage(role: .agent, text: text)
                self?.agentState = .agentSpeaking
            }
        }

        deepgramService.onAgentStartedSpeaking = { [weak self] in
            Task { @MainActor in
                self?.agentState = .agentSpeaking
            }
        }

        deepgramService.onAgentAudioDone = { [weak self] in
            Task { @MainActor in
                self?.agentState = .listening
                if self?.isMuted == false {
                    try? self?.audioManager.startCapture()
                }
            }
        }

        deepgramService.onAudioReceived = { [weak self] data in
            self?.audioManager.playAudioData(data)
        }

        // Handle function call results (manga search results for UI)
        deepgramService.onFunctionCallRequest = { [weak self] _, name, args in
            if name == "search_manga_results", let results = args["results"] as? [Manga] {
                Task { @MainActor in
                    self?.searchResults = results
                }
            }
        }

        // Forward mic audio to Deepgram
        audioManager.onAudioCaptured = { [weak self] data in
            self?.deepgramService.sendAudio(data)
        }
    }

    // MARK: - Actions

    func startConversation() {
        guard agentState == .idle || isErrorState() else { return }

        Task {
            // Check mic permission first
            if !audioManager.micPermissionGranted {
                let granted = await audioManager.requestMicPermission()
                print("[VoiceAgent] Microphone permission granted: \(granted)")
                guard granted else {
                    errorMessage = "Microphone access is required to use the voice assistant."
                    agentState = .error("Microphone access denied")
                    return
                }
            }

            // Clear previous state
            messages.removeAll()
            searchResults.removeAll()
            errorMessage = nil

            // Start playback engine first
            do {
                try audioManager.startPlaybackEngine()
            } catch {
                errorMessage = "Failed to start audio: \(error.localizedDescription)"
                agentState = .error(error.localizedDescription)
                return
            }

            // Connect to Deepgram
            deepgramService.connect()
        }
    }

    func stopConversation() {
        audioManager.stopAll()
        deepgramService.disconnect()
        agentState = .idle
    }

//    func finishSpeaking() {
//        guard agentState == .listening else { return }
//
//        audioManager.stopCapture()
//        deepgramService.sendSilence()
//        agentState = .agentThinking
//        print("[VoiceAgent] Finished speaking, waiting for Deepgram transcript/agent response")
//    }

    func toggleMute() {
        isMuted.toggle()

        if isMuted {
            audioManager.stopCapture()
        } else {
            try? audioManager.startCapture()
        }
    }

    // MARK: - Messages

    private func addMessage(role: ConversationMessage.Role, text: String) {
        let message = ConversationMessage(role: role, text: text, timestamp: Date())
        messages.append(message)
    }

    private func addSystemMessage(_ text: String) {
        addMessage(role: .system, text: text)
    }

    // MARK: - Helpers

    private func isErrorState() -> Bool {
        if case .error = agentState { return true }
        return false
    }

    var isActive: Bool {
        switch agentState {
        case .listening, .agentThinking, .agentSpeaking:
            return true
        default:
            return false
        }
    }

    var statusText: String {
        switch agentState {
        case .idle:
            return "Tap to start talking"
        case .connecting:
            return "Connecting..."
        case .listening:
            return isMuted ? "Muted" : "Listening..."
        case .agentThinking:
            return "AI thinking..."
        case .agentSpeaking:
            return "AI is speaking..."
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}
