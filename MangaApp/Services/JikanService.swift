import Foundation

final class JikanService: MangaServiceProtocol {
    static let shared = JikanService()

    private let baseURL = "https://api.jikan.moe/v4"
    private let session: URLSession
    private let mangaDexService = MangaDexService.shared

    private var titleCache: [String: String] = [:]
    private var mangaDexIdCache: [String: String] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Fetch Manga List

    func fetchMangaList(limit: Int, offset: Int, tagIds: [String]) async throws -> [Manga] {
        let page = (offset / max(limit, 1)) + 1

        var components = URLComponents(string: "\(baseURL)/manga")
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(min(limit, 25))"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "order_by", value: "popularity"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "sfw", value: "true")
        ]

        if !tagIds.isEmpty {
            queryItems.append(URLQueryItem(name: "genres", value: tagIds.joined(separator: ",")))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else { throw APIError.invalidURL }

        let response: JikanMangaResponse = try await request(url: url)
        let mangaList = response.data.map { mapManga(from: $0) }

        for item in response.data {
            titleCache["\(item.malId)"] = item.title
        }

        return mangaList
    }

    // MARK: - Search

    func searchManga(query: String, limit: Int) async throws -> [Manga] {
        var components = URLComponents(string: "\(baseURL)/manga")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(min(limit, 25))"),
            URLQueryItem(name: "order_by", value: "popularity"),
            URLQueryItem(name: "sort", value: "asc"),
            URLQueryItem(name: "sfw", value: "true")
        ]

        guard let url = components?.url else { throw APIError.invalidURL }

        let response: JikanMangaResponse = try await request(url: url)
        let mangaList = response.data.map { mapManga(from: $0) }

        for item in response.data {
            titleCache["\(item.malId)"] = item.title
        }

        return mangaList
    }

    // MARK: - Fetch Tags

    func fetchTags() async throws -> [MangaTag] {
        guard let url = URL(string: "\(baseURL)/genres/manga") else {
            throw APIError.invalidURL
        }

        let response: JikanGenreResponse = try await request(url: url)
        var seen = Set<Int>()
        return response.data
            .filter { seen.insert($0.malId).inserted }
            .map { MangaTag(id: "\($0.malId)", name: $0.name, group: "genre") }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Fetch Chapters (resolve MAL ID -> MangaDex UUID, then use MangaDex)

    func fetchChapters(mangaId: String, limit: Int, offset: Int) async throws -> [Chapter] {
        let mangaDexId = try await resolveMangaDexId(malId: mangaId)
        return try await mangaDexService.fetchChapters(mangaId: mangaDexId, limit: limit, offset: offset)
    }

    // MARK: - Fetch Chapter Pages (pure MangaDex)

    func fetchChapterPages(chapterId: String) async throws -> [MangaPage] {
        try await mangaDexService.fetchChapterPages(chapterId: chapterId)
    }

    // MARK: - Fetch Manga By IDs

    func fetchMangaByIds(_ ids: [String]) async throws -> [Manga] {
        guard !ids.isEmpty else { return [] }

        var results: [Manga] = []

        for (index, malId) in ids.enumerated() {
            if index > 0 {
                try await Task.sleep(nanoseconds: 350_000_000)
            }

            guard let url = URL(string: "\(baseURL)/manga/\(malId)") else { continue }

            do {
                let response: JikanMangaDetailResponse = try await request(url: url)
                results.append(mapManga(from: response.data))
                titleCache[malId] = response.data.title
            } catch {
                continue
            }
        }

        return results
    }

    // MARK: - MangaDex ID Resolution

    private func resolveMangaDexId(malId: String) async throws -> String {
        if let cached = mangaDexIdCache[malId] {
            return cached
        }

        guard let title = titleCache[malId] else {
            throw APIError.invalidResponse
        }

        var components = URLComponents(string: "https://api.mangadex.org/manga")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "en")
        ]

        guard let url = components?.url else { throw APIError.invalidURL }

        let maxRetries = 3
        var lastError: Error = APIError.serverError(404)

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                let response: MangaListResponse = try await mangaDexService.requestPublic(url: url)

                for manga in response.data {
                    if let malLink = manga.attributes.links?["mal"], malLink == malId {
                        mangaDexIdCache[malId] = manga.id
                        return manga.id
                    }
                }

                if let first = response.data.first {
                    mangaDexIdCache[malId] = first.id
                    return first.id
                }

                throw APIError.serverError(404)
            } catch {
                lastError = error
                if case APIError.serverError(404) = error { throw error }
                continue
            }
        }

        throw lastError
    }

    // MARK: - Mapping

    private func mapManga(from item: JikanManga) -> Manga {
        let coverURL = item.images?.jpg?.largeImageUrl ?? item.images?.jpg?.imageUrl

        return Manga(
            id: "\(item.malId)",
            title: item.title,
            description: item.synopsis ?? "No description available.",
            coverURL: coverURL.flatMap { URL(string: $0) },
            status: item.status,
            year: nil,
            tags: item.genres?.map { $0.name } ?? [],
            score: item.score
        )
    }

    // MARK: - Generic Request

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

// MARK: - Jikan API Response Models

private struct JikanMangaResponse: Codable {
    let pagination: JikanPagination?
    let data: [JikanManga]
}

private struct JikanMangaDetailResponse: Codable {
    let data: JikanManga
}

private struct JikanPagination: Codable {
    let lastVisiblePage: Int?
    let hasNextPage: Bool?

    enum CodingKeys: String, CodingKey {
        case lastVisiblePage = "last_visible_page"
        case hasNextPage = "has_next_page"
    }
}

private struct JikanManga: Codable {
    let malId: Int
    let title: String
    let images: JikanImages?
    let synopsis: String?
    let status: String?
    let score: Double?
    let genres: [JikanGenre]?

    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case title, images, synopsis, status, score, genres
    }
}

private struct JikanImages: Codable {
    let jpg: JikanImageUrls?
}

private struct JikanImageUrls: Codable {
    let imageUrl: String?
    let smallImageUrl: String?
    let largeImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case smallImageUrl = "small_image_url"
        case largeImageUrl = "large_image_url"
    }
}

private struct JikanGenreResponse: Codable {
    let data: [JikanGenre]
}

private struct JikanGenre: Codable {
    let malId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case name
    }
}
