import Foundation

protocol MangaServiceProtocol {
    func fetchTags() async throws -> [MangaTag]
    func fetchMangaList(limit: Int, offset: Int, tagIds: [String]) async throws -> [Manga]
    func fetchMangaByIds(_ ids: [String]) async throws -> [Manga]
    func searchManga(query: String, limit: Int) async throws -> [Manga]
    func fetchChapters(mangaId: String, limit: Int, offset: Int) async throws -> [Chapter]
    func fetchChapterPages(chapterId: String) async throws -> [MangaPage]
}

extension MangaServiceProtocol {
    func fetchMangaList(limit: Int = 20, offset: Int = 0, tagIds: [String] = []) async throws -> [Manga] {
        try await fetchMangaList(limit: limit, offset: offset, tagIds: tagIds)
    }

    func searchManga(query: String, limit: Int = 20) async throws -> [Manga] {
        try await searchManga(query: query, limit: limit)
    }

    func fetchChapters(mangaId: String, limit: Int = 100, offset: Int = 0) async throws -> [Chapter] {
        try await fetchChapters(mangaId: mangaId, limit: limit, offset: offset)
    }
}


