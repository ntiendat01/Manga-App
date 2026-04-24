import SwiftUI

struct MangaCard: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: manga.coverURL, contentMode: .fill)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let score = manga.score, score > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.1f", score))
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(6)
                }
            }

            Text(manga.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview Helper

extension Manga {
    static let preview = Manga(
        id: "preview-id",
        title: "Sample Manga Title",
        description: "A sample manga description for previewing the UI.",
        coverURL: nil,
        status: "ongoing",
        year: 2024,
        tags: ["Action", "Adventure"],
        score: 8.5
    )
}
