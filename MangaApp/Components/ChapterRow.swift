import SwiftUI

struct ChapterRow: View {
    let chapter: Chapter
    var isLastRead: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chapter \(chapter.chapterNumber)")
                    .font(.headline)

                if chapter.title != "Chapter \(chapter.chapterNumber)" {
                    Text(chapter.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLastRead {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }

            if chapter.pageCount > 0 {
                Text("\(chapter.pageCount)p")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Helper

extension Chapter {
    static let preview = Chapter(
        id: "preview-chapter",
        chapterNumber: "1",
        title: "The Beginning",
        volume: "1",
        pageCount: 24,
        language: "en"
    )
}
