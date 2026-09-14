import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = MangaListViewModel()
    @State private var showScrollToTop = false

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        Color.clear.frame(height: 0).id("homeTop")

                        if !viewModel.availableTags.isEmpty {
                            GenreChipsView(
                                tags: viewModel.availableTags,
                                selectedIds: viewModel.selectedTagIds,
                                onToggle: viewModel.toggleTag,
                                onClear: viewModel.clearTags
                            )
                        }

                        if let error = viewModel.errorMessage, viewModel.mangaList.isEmpty {
                            errorView(error)
                        } else if viewModel.mangaList.isEmpty && !viewModel.isLoading && viewModel.hasSearched {
                            emptySearchView
                        } else {
                            mangaGrid
                        }
                    }

                    if showScrollToTop {
                        Button {
                            withAnimation { proxy.scrollTo("homeTop") }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.pink)
                                .frame(width: 44, height: 44)
                                .background(.thinMaterial, in: Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 28)
                        .opacity(0.7)
                        .transition(.opacity)
                    }
                }
            }
            .background(Color.lightPink.ignoresSafeArea())
            .navigationTitle("Manga")
            .searchable(text: $viewModel.searchText, prompt: "Search manga...")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .onChange(of: viewModel.searchText) { newValue in
                if newValue.isEmpty {
                    Task { await viewModel.fetchManga() }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.mangaList.isEmpty {
                    ProgressView("Loading manga...")
                }
            }
            .task {
                async let tagsTask: () = viewModel.fetchTags()
                async let mangaTask: () = {
                    if await viewModel.mangaList.isEmpty {
                        await viewModel.fetchManga()
                    }
                }()
                _ = await (tagsTask, mangaTask)
            }
            .refreshable {
                await viewModel.fetchManga()
            }
        }
    }

    // MARK: - Subviews

    private var mangaGrid: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(viewModel.mangaList) { manga in
                NavigationLink(value: manga) {
                    MangaCard(manga: manga)
                }
                .buttonStyle(.plain)
                .onAppear {
                    let index = viewModel.mangaList.firstIndex(of: manga) ?? 0
                    showScrollToTop = index > 5

                    if manga == viewModel.mangaList.last {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoading && !viewModel.mangaList.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .navigationDestination(for: Manga.self) { manga in
            MangaDetailView(manga: manga)
        }
    }

    private var emptySearchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No results")
                .font(.headline)

            Text("Try searching with different keywords.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

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
                Task { await viewModel.fetchManga() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hashable Conformance

extension Manga: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

