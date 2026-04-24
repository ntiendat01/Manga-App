import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var pages: [MangaPage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let chapter: Chapter
    let mangaId: String
    private let apiService: MangaServiceProtocol

    init(chapter: Chapter, mangaId: String, apiService: MangaServiceProtocol = ServiceProvider.shared.activeService) {
        self.chapter = chapter
        self.mangaId = mangaId
        self.apiService = apiService
    }

    func fetchPages() async {
        guard pages.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let results = try await apiService.fetchChapterPages(chapterId: chapter.id)
            pages = results
            FavoriteService.shared.setLastReadChapter(chapter.id, for: mangaId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
