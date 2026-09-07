import Foundation

/// Deepgram Voice Agent WebSocket service.
/// Connects to wss://agent.deepgram.com/v1/agent/converse and handles
/// the full STT → LLM → TTS pipeline with function calling support.
final class DeepgramService: NSObject, ObservableObject {

    // MARK: - Configuration

    /// Configure this locally through the DEEPGRAM_API_KEY environment variable
    /// or a private build setting. Do not commit API keys to the repository.
    private var apiKey: String? {
        let environmentKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"]
        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        let bundleKey = Bundle.main.object(forInfoDictionaryKey: "DEEPGRAM_API_KEY") as? String
        if let bundleKey, !bundleKey.isEmpty, !bundleKey.contains("$(") {
            return bundleKey
        }

        return nil
    }
    private let agentEndpoint = "wss://agent.deepgram.com/v1/agent/converse"

    // MARK: - State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastTranscript: String = ""
    @Published var lastAgentText: String = ""

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    // MARK: - Callbacks

    /// Called when audio data is received from TTS (binary)
    var onAudioReceived: ((Data) -> Void)?

    /// Called when the agent starts/stops speaking
    var onAgentStartedSpeaking: (() -> Void)?
    var onAgentStoppedSpeaking: (() -> Void)?

    /// Called when user speech is transcribed
    var onUserTranscript: ((String) -> Void)?

    /// Called when the agent produces a text response
    var onAgentText: ((String) -> Void)?

    /// Called when a function call is requested (for search_manga)
    var onFunctionCallRequest: ((_ id: String, _ name: String, _ arguments: [String: Any]) -> Void)?

    /// Called when agent audio is fully done
    var onAgentAudioDone: (() -> Void)?
    
    /// Called when the agent is processing a response
    var onAgentThinking: (() -> Void)?

    /// Called when the conversation is ready (Welcome message received)
    var onReady: (() -> Void)?

    // MARK: - WebSocket

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isReceiving = false
    private var isDisconnecting = false
    private var sentAudioChunkCount = 0
    private var receivedTextMessageCount = 0

    // MARK: - Manga Search Service

    private let mangaService = MangaDexService.shared

    // MARK: - Connect

    func connect() {
        guard connectionState == .disconnected || isErrorState() else { return }

        connectionState = .connecting
        isDisconnecting = false
        sentAudioChunkCount = 0
        receivedTextMessageCount = 0

        guard let url = URL(string: agentEndpoint) else {
            connectionState = .error("Invalid endpoint URL")
            return
        }

        guard let apiKey else {
            connectionState = .error("Missing DEEPGRAM_API_KEY configuration")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        startReceiving()
    }

    /// Disconnect the WebSocket
    func disconnect() {
        isDisconnecting = true
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isReceiving = false

        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    // MARK: - Send Settings

    /// Send the initial Settings message to configure the voice agent
    private func sendSettings() {
        let settings: [String: Any] = [
            "type": "Settings",
            "mip_opt_out": true,
            "audio": [
                "input": [
                    "encoding": "linear16",
                    "sample_rate": 16000
                ],
                "output": [
                    "encoding": "linear16",
                    "sample_rate": 24000,
                    "container": "none"
                ]
            ],
            "agent": [
                "listen": [
                    "provider": [
                        "type": "deepgram",
                        "model": "nova-3",
                        "language": "vi",
                        "smart_format": true
                    ]
                ],
                "think": [
                    "provider": [
                        "type": "open_ai",
                        "model": "gpt-4o-mini",
                        "temperature": 0.7
                    ],
                    "prompt": """
                    You are MangaBot, a friendly and knowledgeable AI manga assistant inside a manga reading app.
                    The user is speaking Vietnamese. Understand Vietnamese questions and answer in concise, natural Vietnamese.
                    
                    Your primary job is to help users discover and find manga. When users ask about manga, use the search_manga function to find results.
                    
                    Guidelines:
                    - Be enthusiastic about manga!
                    - When presenting search results, mention the title and a brief description.
                    - If no results are found, suggest alternative search terms.
                    - Keep responses concise and conversational since this is a voice interface.
                    - You can discuss manga genres, recommendations, and general manga topics.
                    - If users ask about something unrelated to manga, politely redirect them.
                    """,
                    "functions": [
                        [
                            "name": "search_manga",
                            "description": "Search for manga by title, genre, or keyword. Use this whenever the user asks to find, search, or look for manga.",
                            "parameters": [
                                "type": "object",
                                "properties": [
                                    "query": [
                                        "type": "string",
                                        "description": "The search query - can be a manga title, genre, or keyword"
                                    ]
                                ],
                                "required": ["query"]
                            ] as [String: Any]
                        ] as [String: Any]
                    ]
                ] as [String: Any],
                "speak": [
                    "provider": [
                        "type": "deepgram",
                        "model": "aura-2-thalia-en"
                    ]
                ]
            ] as [String: Any]
        ]

        sendJSON(settings)
    }

    // MARK: - Send Audio

    /// Send raw PCM audio data to Deepgram
    func sendAudio(_ data: Data) {
        guard connectionState == .connected else {
            if sentAudioChunkCount == 0 {
                print("[Deepgram] Dropping audio because connection is not ready: \(connectionState)")
            }
            return
        }

        sentAudioChunkCount += 1
        if sentAudioChunkCount <= 10 || sentAudioChunkCount % 50 == 0 {
            print("[Deepgram] Sending audio chunk #\(sentAudioChunkCount): \(data.count) bytes")
        }

        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("[Deepgram] Audio send error: \(error.localizedDescription)")
            }
        }
    }

    /// Send a short span of silent PCM to help the server endpoint/finalize the current utterance.
    func sendSilence(duration: TimeInterval = 1.2) {
        let chunkDuration = 0.1
        let chunkCount = Int(duration / chunkDuration)
        let silentPCM16Chunk = Data(repeating: 0, count: 3200) // 100ms @ 16kHz mono Int16

        for _ in 0..<chunkCount {
            sendAudio(silentPCM16Chunk)
        }

        print("[Deepgram] Sent \(chunkCount) silence chunks to finalize utterance")
    }

    // MARK: - Send Function Call Response

    /// Send the result of a function call back to Deepgram
    func sendFunctionCallResponse(id: String, name: String, content: String) {
        let response: [String: Any] = [
            "type": "FunctionCallResponse",
            "id": id,
            "name": name,
            "content": content
        ]
        sendJSON(response)
    }

    // MARK: - Handle Function Calls

    /// Process a search_manga function call
    func handleSearchManga(callId: String, query: String) {
        Task {
            do {
                let results = try await mangaService.searchManga(query: query, limit: 5)

                let responseText: String
                if results.isEmpty {
                    responseText = "No manga found for '\(query)'. Try a different search term."
                } else {
                    let mangaDescriptions = results.prefix(5).enumerated().map { index, manga in
                        let desc = manga.description.prefix(80)
                        return "\(index + 1). \(manga.title) - \(desc)..."
                    }.joined(separator: ". ")

                    responseText = "I found \(results.count) manga for '\(query)': \(mangaDescriptions)"
                }

                sendFunctionCallResponse(id: callId, name: "search_manga", content: responseText)

                // Also notify the VM about the results for UI display
                await MainActor.run {
                    self.onFunctionCallRequest?(callId, "search_manga_results", ["results": results])
                }
            } catch {
                sendFunctionCallResponse(
                    id: callId,
                    name: "search_manga",
                    content: "Sorry, I encountered an error while searching: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Receiving Messages

    private func startReceiving() {
        guard !isReceiving else { return }
        isReceiving = true
        receiveNextMessage()
    }

    private func receiveNextMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // Binary data = audio from TTS
                    self.onAudioReceived?(data)

                case .string(let text):
                    self.handleTextMessage(text)

                @unknown default:
                    break
                }

                // Continue receiving
                self.receiveNextMessage()

            case .failure(let error):
                if self.isDisconnecting { return }

                print("[Deepgram] Receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if self.connectionState != .disconnected {
                        self.connectionState = .error(error.localizedDescription)
                    }
                }
                self.isReceiving = false
            }
        }
    }

    // MARK: - Parse Server Events

    private func handleTextMessage(_ text: String) {
        receivedTextMessageCount += 1
        if receivedTextMessageCount <= 20 {
            print("[Deepgram] Text event #\(receivedTextMessageCount): \(text)")
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "Welcome":
            print("[Deepgram] Welcome received")
            // Connection is ready, send settings
            DispatchQueue.main.async {
                self.connectionState = .connected
            }
            sendSettings()

        case "SettingsApplied":
            print("[Deepgram] Settings applied successfully")
            DispatchQueue.main.async {
                self.onReady?()
            }

        case "AgentStartedSpeaking":
            DispatchQueue.main.async {
                self.onAgentStartedSpeaking?()
            }

        case "AgentAudioDone":
            DispatchQueue.main.async {
                self.onAgentAudioDone?()
            }

        case "AgentThinking":
            DispatchQueue.main.async {
                self.onAgentThinking?()
            }

        case "ConversationText":
            if let role = json["role"] as? String, let content = json["content"] as? String {
                DispatchQueue.main.async {
                    if role == "user" {
                        self.lastTranscript = content
                        self.onUserTranscript?(content)
                    } else if role == "assistant" {
                        self.lastAgentText = content
                        self.onAgentText?(content)
                    }
                }
            }

        case "FunctionCallRequest":
            if let functions = json["functions"] as? [[String: Any]] {
                for function in functions {
                    guard let id = function["id"] as? String,
                          let name = function["name"] as? String,
                          let argsString = function["arguments"] as? String,
                          let argsData = argsString.data(using: .utf8),
                          let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
                    else { continue }

                    if name == "search_manga", let query = args["query"] as? String {
                        handleSearchManga(callId: id, query: query)
                    }
                }
            }

        case "UserStartedSpeaking":
            // User started talking — could be used for barge-in UI
            break

        case "Error":
            let message = json["message"] as? String ?? json["err_msg"] as? String ?? "Unknown error"
            print("[Deepgram] Error JSON: \(json)")
            DispatchQueue.main.async {
                self.connectionState = .error(message)
            }

        case "Warning":
            let message = json["message"] as? String ?? "Unknown warning"
            print("[Deepgram] Warning: \(message), JSON: \(json)")

        default:
            print("[Deepgram] Unhandled event: \(type)")
            print("[Deepgram] Event JSON: \(json)")
        }
    }

    // MARK: - Helpers

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else {
            print("[Deepgram] Failed to serialize JSON")
            return
        }

        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("[Deepgram] Send error: \(error.localizedDescription)")
            }
        }
    }

    private func isErrorState() -> Bool {
        if case .error = connectionState { return true }
        return false
    }
}

// MARK: - URLSessionWebSocketDelegate

extension DeepgramService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[Deepgram] WebSocket connected")
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let closeReason = reason.flatMap { String(data: $0, encoding: .utf8) }
        print("[Deepgram] WebSocket closed: \(closeCode), reason: \(closeReason ?? "none")")
        DispatchQueue.main.async {
            if self.isDisconnecting || closeCode == .normalClosure {
                self.connectionState = .disconnected
            } else if self.isErrorState() {
                return
            } else {
                self.connectionState = .error("WebSocket closed unexpectedly: \(closeCode.rawValue)")
            }
        }
        isReceiving = false
    }
}
