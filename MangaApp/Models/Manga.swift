import Foundation

// MARK: - MangaDex API Response

struct MangaListResponse: Codable {
    let result: String
    let data: [MangaData]
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaData: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: MangaAttributes
    let relationships: [Relationship]
}

struct MangaAttributes: Codable {
    let title: LocalizedString
    let description: LocalizedString?
    let status: String?
    let year: Int?
    let contentRating: String?
    let tags: [Tag]?
    let links: [String: String]?
}

struct LocalizedString: Codable {
    let en: String?
    let ja: String?
    let jaRo: String?

    enum CodingKeys: String, CodingKey {
        case en
        case ja
        case jaRo = "ja-ro"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        en = try container.decodeIfPresent(String.self, forKey: .en)
        ja = try container.decodeIfPresent(String.self, forKey: .ja)
        jaRo = try container.decodeIfPresent(String.self, forKey: .jaRo)
    }

    var bestTitle: String {
        en ?? jaRo ?? ja ?? "Unknown"
    }
}

struct Relationship: Codable {
    let id: String
    let type: String
    let attributes: RelationshipAttributes?
}

struct RelationshipAttributes: Codable {
    let fileName: String?
}

struct Tag: Codable {
    let id: String
    let attributes: TagAttributes?
}

struct TagAttributes: Codable {
    let name: LocalizedString?
}

// MARK: - MangaDex Tag API Response

struct TagListResponse: Codable {
    let result: String
    let data: [TagData]
}

struct TagData: Codable, Identifiable {
    let id: String
    let attributes: TagDataAttributes
}

struct TagDataAttributes: Codable {
    let name: LocalizedString
    let group: String
}

// MARK: - Tag Domain Model

struct MangaTag: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String

    static func from(data: TagData) -> MangaTag {
        MangaTag(
            id: data.id,
            name: data.attributes.name.bestTitle,
            group: data.attributes.group
        )
    }
}

// MARK: - App Domain Model

struct Manga: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let coverURL: URL?
    let status: String?
    let year: Int?
    let tags: [String]
    let score: Double?

    static func == (lhs: Manga, rhs: Manga) -> Bool {
        lhs.id == rhs.id
    }

    static func from(data: MangaData) -> Manga {
        let coverFilename = data.relationships
            .first(where: { $0.type == "cover_art" })?
            .attributes?.fileName

        let coverURL: URL? = coverFilename.flatMap {
            URL(string: "https://uploads.mangadex.org/covers/\(data.id)/\($0).256.jpg")
        }

        let tags = data.attributes.tags?.compactMap {
            $0.attributes?.name?.bestTitle
        } ?? []

        return Manga(
            id: data.id,
            title: data.attributes.title.bestTitle,
            description: data.attributes.description?.bestTitle ?? "No description available.",
            coverURL: coverURL,
            status: data.attributes.status,
            year: data.attributes.year,
            tags: tags,
            score: nil
        )
    }
}
