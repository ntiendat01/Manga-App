import SwiftUI

struct MangaDetailView: View {
    let manga: Manga
    @StateObject private var viewModel: MangaDetailViewModel
    @ObservedObject private var favoriteService = FavoriteService.shared

    init(manga: Manga) {
        self.manga = manga
        _viewModel = StateObject(wrappedValue: MangaDetailViewModel(manga: manga))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                infoSection
                chapterSection
            }
        }
        .background(Color.lightPink.ignoresSafeArea())
        .navigationTitle(manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoriteService.toggleFavorite(manga.id)
                } label: {
                    Image(systemName: favoriteService.isFavorite(manga.id) ? "heart.fill" : "heart")
                        .foregroundStyle(favoriteService.isFavorite(manga.id) ? .red : .primary)
                }
            }
        }
        .task {
            await viewModel.fetchChapters()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: manga.coverURL, contentMode: .fill)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, Color.lightPink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(manga.title)
                .font(.title2)
                .fontWeight(.bold)

            if let status = manga.status {
                HStack(spacing: 8) {
                    statusBadge(status)
                    if let year = manga.year {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !manga.tags.isEmpty {
                tagList
            }

            Text(manga.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(6)
        }
        .padding()
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "ongoing": return .green
        case "completed": return .blue
        case "hiatus": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }

    private var tagList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manga.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Chapters

    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chapters")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                if !viewModel.chapters.isEmpty {
                    Text("\(viewModel.chapters.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.chapters.isEmpty {
                Text("No chapters available in English.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    let lastReadId = FavoriteService.shared.lastReadChapter(for: manga.id)

                    ForEach(viewModel.chapters) { chapter in
                        NavigationLink {
                            ReaderView(chapter: chapter, mangaId: manga.id)
                        } label: {
                            ChapterRow(
                                chapter: chapter,
                                isLastRead: chapter.id == lastReadId
                            )
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
