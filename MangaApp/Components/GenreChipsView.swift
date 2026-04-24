import SwiftUI

struct GenreChipsView: View {
    let tags: [MangaTag]
    let selectedIds: Set<String>
    let onToggle: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                allChip

                ForEach(tags) { tag in
                    chipButton(tag: tag)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var allChip: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onClear()
            }
        } label: {
            Text("All")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedIds.isEmpty ? Color.pink : Color.secondary.opacity(0.1))
                .foregroundStyle(selectedIds.isEmpty ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func chipButton(tag: MangaTag) -> some View {
        let isSelected = selectedIds.contains(tag.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggle(tag.id)
            }
        } label: {
            Text(tag.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.pink : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
