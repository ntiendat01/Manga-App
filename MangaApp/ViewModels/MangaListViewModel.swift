import Foundation

@MainActor
final class MangaListViewModel: ObservableObject {
    @Published var mangaList: [Manga] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var hasSearched = false

    @Published var availableTags: [MangaTag] = []
    @Published var selectedTagIds: Set<String> = []
    @Published var isLoadingTags = false

    private let apiService: MangaServiceProtocol
    private var currentOffset = 0
    private let pageSize = 20
    private var canLoadMore = true

    init(apiService: MangaServiceProtocol = ServiceProvider.shared.activeService) {
        self.apiService = apiService
    }

    // MARK: - Tags

    func fetchTags() async {
        guard availableTags.isEmpty else { return }
        isLoadingTags = true

        do {
            availableTags = try await apiService.fetchTags()
        } catch {
            // Tags are non-critical; silently fail
        }

        isLoadingTags = false
    }

    func toggleTag(_ tagId: String) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }

        Task { await fetchManga() }
    }

    func clearTags() {
        guard !selectedTagIds.isEmpty else { return }
        selectedTagIds.removeAll()
        Task { await fetchManga() }
    }

    // MARK: - Manga List

    func fetchManga() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = false

        do {
            let results = try await apiService.fetchMangaList(
                limit: pageSize,
                offset: 0,
                tagIds: Array(selectedTagIds)
            )
            mangaList = results
            currentOffset = results.count
            canLoadMore = results.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true

        do {
            let results = try await apiService.fetchMangaList(
                limit: pageSize,
                offset: currentOffset,
                tagIds: Array(selectedTagIds)
            )
            mangaList.append(contentsOf: results)
            currentOffset += results.count
            canLoadMore = results.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await fetchManga()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await apiService.searchManga(query: query)
            mangaList = results
            canLoadMore = false
            hasSearched = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
