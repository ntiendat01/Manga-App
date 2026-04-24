import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lightPink.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading favorites...")
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.isEmpty {
                    emptyView
                } else {
                    favoritesGrid
                }
            }
            .navigationTitle("Favorites")
            .task {
                await viewModel.fetchFavorites()
            }
        }
    }

    // MARK: - Grid

    private var favoritesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.mangaList) { manga in
                    NavigationLink(value: manga) {
                        MangaCard(manga: manga)
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.removeFavorite(manga)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .navigationDestination(for: Manga.self) { manga in
                MangaDetailView(manga: manga)
            }
        }
        .refreshable {
            await viewModel.fetchFavorites()
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No favorites yet")
                .font(.headline)

            Text("Tap the heart icon on a manga to add it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.fetchFavorites() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
