import SwiftUI

struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showScrollToTop = false

    init(chapter: Chapter, mangaId: String) {
        _viewModel = StateObject(wrappedValue: ReaderViewModel(chapter: chapter, mangaId: mangaId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.pages.isEmpty {
                headerBar
            }

            ZStack {
                Color.lightPink.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading pages...")
                        .tint(.pink)
                        .foregroundStyle(.primary)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.pages.isEmpty {
                    emptyChapterView
                } else {
                    pageContent
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()
        }
        .background(Color.lightPink.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.fetchPages()
        }
    }

    // MARK: - Page Content

    private var pageContent: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    Color.clear.frame(height: 0).id("top")

                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.pages) { page in
                            CachedAsyncImage(url: page.imageURL, contentMode: .fit)
                                .frame(maxWidth: .infinity, minHeight: pagePlaceholderHeight)
                                .background(Color.lightPink)
                                .onAppear { showScrollToTop = page.id > 2 }
                        }
                    }
                }

                if showScrollToTop {
                    Button {
                        withAnimation { proxy.scrollTo("top") }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.pink)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                    .opacity(0.7)
                    .transition(.opacity)
                }
            }
        }
    }

    private var pagePlaceholderHeight: CGFloat {
        UIScreen.main.bounds.width * 1.4
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.pink)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial, in: Circle())
            }

            Spacer()

            Text("Ch. \(viewModel.chapter.chapterNumber)")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())

            Spacer()

            Text("\(viewModel.pages.count)p")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.lightPink)
    }

    // MARK: - Empty Chapter

    private var emptyChapterView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No image")
                .font(.headline)

            Text("Something Error")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.pink)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.fetchPages() }
            }
            .buttonStyle(.bordered)
            .tint(.pink)

            Button("Go Back") {
                dismiss()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
