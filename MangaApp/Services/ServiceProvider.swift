import Foundation

final class ServiceProvider: ObservableObject {
    static let shared = ServiceProvider()

    enum Source: String, CaseIterable, Identifiable {
        case mangadex = "MangaDex"
        case jikan = "Jikan (MAL)"

        var id: String { rawValue }
    }

    @Published var currentSource: Source {
        didSet {
            UserDefaults.standard.set(currentSource.rawValue, forKey: "api_source")
        }
    }

    var activeService: MangaServiceProtocol {
        switch currentSource {
        case .mangadex:
            return mangaDexService
        case .jikan:
            return jikanService
        }
    }

    private let mangaDexService = MangaDexService.shared
    private let jikanService = JikanService.shared

    private init() {
        let saved = UserDefaults.standard.string(forKey: "api_source") ?? Source.mangadex.rawValue
        currentSource = Source(rawValue: saved) ?? .jikan
    }
}
