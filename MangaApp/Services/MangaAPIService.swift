import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError(let error):
            return "Failed to decode: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with status code \(code)"
        }
    }
}

final class MangaDexService: MangaServiceProtocol {
    static let shared = MangaDexService()

    private let baseURL = "https://api.mangadex.org"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Fetch Tags

    func fetchTags() async throws -> [MangaTag] {
        guard let url = URL(string: "\(baseURL)/manga/tag") else {
            throw APIError.invalidURL
        }

        let response: TagListResponse = try await request(url: url)
        return response.data
            .map(MangaTag.from)
            .filter { $0.group == "genre" || $0.group == "theme" }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Fetch Manga List

    func fetchMangaList(limit: Int = 20, offset: Int = 0, tagIds: [String] = []) async throws -> [Manga] {
        var components = URLComponents(string: "\(baseURL)/manga")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "order[followedCount]", value: "desc"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "hasAvailableChapters", value: "true"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "en")
        ]

        for tagId in tagIds {
            components?.queryItems?.append(
                URLQueryItem(name: "includedTags[]", value: tagId)
            )
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: MangaListResponse = try await request(url: url)
        return response.data.map(Manga.from)
    }

    // MARK: - Fetch Manga By IDs

    func fetchMangaByIds(_ ids: [String]) async throws -> [Manga] {
        guard !ids.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/manga")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(ids.count)"),
            URLQueryItem(name: "includes[]", value: "cover_art")
        ]

        for id in ids {
            components?.queryItems?.append(
                URLQueryItem(name: "ids[]", value: id)
            )
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: MangaListResponse = try await request(url: url)
        return response.data.map(Manga.from)
    }

    // MARK: - Search Manga

    func searchManga(query: String, limit: Int = 20) async throws -> [Manga] {
        var components = URLComponents(string: "\(baseURL)/manga")
        components?.queryItems = [
            URLQueryItem(name: "title", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "en")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: MangaListResponse = try await request(url: url)
        return response.data.map(Manga.from)
    }

    // MARK: - Fetch Chapters

    func fetchChapters(mangaId: String, limit: Int = 100, offset: Int = 0) async throws -> [Chapter] {
        var components = URLComponents(string: "\(baseURL)/chapter")
        components?.queryItems = [
            URLQueryItem(name: "manga", value: mangaId),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "translatedLanguage[]", value: "en"),
            URLQueryItem(name: "order[chapter]", value: "asc")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: ChapterListResponse = try await request(url: url)
        return response.data.map(Chapter.from)
    }

    // MARK: - Fetch Chapter Pages

    func fetchChapterPages(chapterId: String) async throws -> [MangaPage] {
        guard let url = URL(string: "\(baseURL)/at-home/server/\(chapterId)") else {
            throw APIError.invalidURL
        }

        let response: AtHomeResponse = try await request(url: url)
        return MangaPage.pages(from: response, dataSaver: true)
    }

    // MARK: - Generic Request

    func requestPublic<T: Decodable>(url: URL) async throws -> T {
        try await request(url: url)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
