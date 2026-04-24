import Foundation

final class FavoriteService: ObservableObject {
    static let shared = FavoriteService()

    private let favoritesKey = "favorite_manga_ids"
    private let lastReadKey = "last_read_chapters"

    @Published private(set) var favoriteIDs: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favoriteIDs = Set(saved)
    }

    func isFavorite(_ mangaId: String) -> Bool {
        favoriteIDs.contains(mangaId)
    }

    func toggleFavorite(_ mangaId: String) {
        if favoriteIDs.contains(mangaId) {
            favoriteIDs.remove(mangaId)
        } else {
            favoriteIDs.insert(mangaId)
        }
        save()
    }

    // MARK: - Last Read Chapter

    func setLastReadChapter(_ chapterId: String, for mangaId: String) {
        var dict = lastReadDictionary()
        dict[mangaId] = chapterId
        UserDefaults.standard.set(dict, forKey: lastReadKey)
    }

    func lastReadChapter(for mangaId: String) -> String? {
        lastReadDictionary()[mangaId]
    }

    // MARK: - Private

    private func save() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
    }

    private func lastReadDictionary() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: lastReadKey) as? [String: String] ?? [:]
    }
}
