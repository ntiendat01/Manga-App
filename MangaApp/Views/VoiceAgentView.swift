import SwiftUI

struct VoiceAgentView: View {
    @StateObject private var viewModel = VoiceAgentViewModel()
    @Namespace private var animation

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.lightPink
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Conversation messages
                    conversationArea
                        .frame(maxHeight: .infinity)

                    // Search results (if any)
                    if !viewModel.searchResults.isEmpty {
                        searchResultsSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom controls
                    controlPanel
                        .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .overlay {
                                if viewModel.isActive {
                                    Circle()
                                        .fill(statusColor.opacity(0.4))
                                        .frame(width: 16, height: 16)
                                        .scaleEffect(viewModel.isActive ? 1.5 : 1.0)
                                        .animation(
                                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                            value: viewModel.isActive
                                        )
                                }
                            }

                        Text("MangaBot")
                            .font(.system(.headline, design: .rounded))
                    }
                }
            }
            .animation(.spring(response: 0.4), value: viewModel.searchResults.isEmpty)
        }
    }



    // MARK: - Conversation Area

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Voice Manga Assistant")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)

                Text("Talk to find your next favorite manga")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Example prompts
            VStack(spacing: 10) {
                examplePrompt("\"Find me action manga\"")
                examplePrompt("\"What's a good romance manga?\"")
                examplePrompt("\"Search for One Piece\"")
            }
            .padding(.top, 8)
        }
    }

    private func examplePrompt(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.pink.opacity(0.1), lineWidth: 1)
                    )
            )
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)

                Text("Found Manga")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    withAnimation { viewModel.searchResults.removeAll() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.searchResults) { manga in
                        NavigationLink(value: manga) {
                            VoiceMangaCard(manga: manga)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.pink.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 8)
        .navigationDestination(for: Manga.self) { manga in
            MangaDetailView(manga: manga)
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Status text
            Text(viewModel.statusText)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: viewModel.statusText)

            HStack(spacing: 32) {
                // Mute button
                if viewModel.isActive {
                    Button(action: viewModel.toggleMute) {
                        Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundColor(viewModel.isMuted ? .red : .primary.opacity(0.7))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 3)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Main action button
                mainActionButton

                // End call button
                if viewModel.isActive {
                    Button(action: viewModel.stopConversation) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.pink.opacity(0.85))
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.pink.opacity(0.12))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.pink.opacity(0.18), lineWidth: 1)
                                    )
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: viewModel.isActive)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: Color.pink.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Main Action Button

    private var mainActionButton: some View {
        Button {
            if viewModel.isActive {
                // Already active — do nothing or could toggle pause
            } else {
                viewModel.startConversation()
            }
        } label: {
            ZStack {
                // Pulsing rings when active
                if viewModel.isActive {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(mainButtonGradient, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .scaleEffect(1.0 + CGFloat(i) * 0.2 + CGFloat(viewModel.audioLevel) * 0.5)
                            .opacity(Double(3 - i) * 0.15)
                            .animation(
                                .easeInOut(duration: 0.8 + Double(i) * 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.2),
                                value: viewModel.isActive
                            )
                    }
                }

                // Main circle
                Circle()
                    .fill(mainButtonGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: buttonShadowColor, radius: viewModel.isActive ? 20 : 8, y: 4)

                // Icon
                Image(systemName: mainButtonIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.agentState == .connecting)
    }

    // MARK: - Computed Properties

    private var mainButtonGradient: LinearGradient {
        switch viewModel.agentState {
        case .idle, .error:
            return LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting:
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .listening:
            return LinearGradient(
                colors: [.green, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .agentThinking:
            return LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .agentSpeaking:
            return LinearGradient(
                colors: [.cyan, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var buttonShadowColor: Color {
        switch viewModel.agentState {
        case .idle, .error: return .purple.opacity(0.4)
        case .connecting: return .orange.opacity(0.4)
        case .listening: return .green.opacity(0.4)
        case .agentThinking: return .blue.opacity(0.4)
        case .agentSpeaking: return .cyan.opacity(0.4)
        }
    }

    private var statusColor: Color {
        switch viewModel.agentState {
        case .idle: return .gray
        case .connecting: return .orange
        case .listening: return .green
        case .agentThinking: return .blue
        case .agentSpeaking: return .cyan
        case .error: return .red
        }
    }

    private var mainButtonIcon: String {
        switch viewModel.agentState {
        case .idle, .error: return "waveform"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .listening: return "waveform"
        case .agentThinking: return "brain"
        case .agentSpeaking: return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        if message.role == .system {
            systemMessageRow
        } else {
            HStack {
                if message.role == .user { Spacer(minLength: 60) }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    chatBubble

                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }

                if message.role == .agent { Spacer(minLength: 60) }
            }
        }
    }

    private var systemMessageRow: some View {
        VStack(spacing: 4) {
            systemBubble
            Text(timeString)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var chatBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .agent {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.pink)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.pink.opacity(0.1)))
            }

            Text(message.text)
                .font(.subheadline)
                .foregroundColor(message.role == .user ? .white : .primary)
                .multilineTextAlignment(message.role == .user ? .trailing : .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(bubbleColor)
                .shadow(color: message.role == .agent ? Color.black.opacity(0.04) : Color.clear, radius: 4, x: 0, y: 2)
        )
    }

    private var systemBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(message.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user:
            return Color.pink.opacity(0.85)
        case .agent:
            return Color.white
        case .system:
            return .clear
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Voice Manga Card

struct VoiceMangaCard: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
            AsyncImage(url: manga.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(Color.gray.opacity(0.5))
                        }
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.05))
                        .overlay { ProgressView().tint(.gray.opacity(0.5)) }
                }
            }
            .frame(width: 110, height: 155)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Title
            Text(manga.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 110, alignment: .leading)
        }
    }
}
