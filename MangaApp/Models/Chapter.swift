import Foundation

// MARK: - MangaDex Chapter API Response

struct ChapterListResponse: Codable {
    let result: String
    let data: [ChapterData]
    let limit: Int
    let offset: Int
    let total: Int
}

struct ChapterData: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: ChapterAttributes
}

struct ChapterAttributes: Codable {
    let volume: String?
    let chapter: String?
    let title: String?
    let translatedLanguage: String?
    let pages: Int?
    let publishAt: String?
}

// MARK: - App Domain Model

struct Chapter: Identifiable, Equatable {
    let id: String
    let chapterNumber: String
    let title: String
    let volume: String?
    let pageCount: Int
    let language: String

    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }

    static func from(data: ChapterData) -> Chapter {
        Chapter(
            id: data.id,
            chapterNumber: data.attributes.chapter ?? "?",
            title: data.attributes.title ?? "Chapter \(data.attributes.chapter ?? "?")",
            volume: data.attributes.volume,
            pageCount: data.attributes.pages ?? 0,
            language: data.attributes.translatedLanguage ?? "unknown"
        )
    }
}
