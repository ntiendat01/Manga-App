import Foundation

@MainActor
final class MangaDetailViewModel: ObservableObject {
    @Published var chapters: [Chapter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let manga: Manga
    private let apiService: MangaServiceProtocol

    init(manga: Manga, apiService: MangaServiceProtocol = ServiceProvider.shared.activeService) {
        self.manga = manga
        self.apiService = apiService
    }

    func fetchChapters() async {
        guard chapters.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let results = try await apiService.fetchChapters(mangaId: manga.id)
            chapters = results
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
