import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var mangaList: [Manga] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService: MangaServiceProtocol
    private let favoriteService = FavoriteService.shared

    init(apiService: MangaServiceProtocol = ServiceProvider.shared.activeService) {
        self.apiService = apiService
    }

    var isEmpty: Bool {
        mangaList.isEmpty && !isLoading
    }

    func fetchFavorites() async {
        let ids = Array(favoriteService.favoriteIDs)
        guard !ids.isEmpty else {
            mangaList = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            mangaList = try await apiService.fetchMangaByIds(ids)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func removeFavorite(_ manga: Manga) {
        favoriteService.toggleFavorite(manga.id)
        mangaList.removeAll { $0.id == manga.id }
    }
}
