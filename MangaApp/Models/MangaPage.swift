import Foundation

// MARK: - MangaDex At-Home API Response

struct AtHomeResponse: Codable {
    let result: String
    let baseUrl: String
    let chapter: AtHomeChapter
}

struct AtHomeChapter: Codable {
    let hash: String
    let data: [String]
    let dataSaver: [String]
}

// MARK: - App Domain Model

struct MangaPage: Identifiable {
    let id: Int
    let imageURL: URL

    static func pages(from response: AtHomeResponse, dataSaver: Bool = false) -> [MangaPage] {
        let filenames = dataSaver ? response.chapter.dataSaver : response.chapter.data
        let quality = dataSaver ? "data-saver" : "data"

        return filenames.enumerated().compactMap { index, filename in
            guard let url = URL(string: "\(response.baseUrl)/\(quality)/\(response.chapter.hash)/\(filename)") else {
                return nil
            }
            return MangaPage(id: index, imageURL: url)
        }
    }
}
