import SwiftUI

/// Sidebar view displaying the book's table of contents as a navigable tree.
struct SidebarView: View {
    let chapters: [Chapter]
    @Binding var selectedChapter: Chapter?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                Text("目录")
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if chapters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No chapters detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedChapter) {
                    ForEach(chapters) { chapter in
                        ChapterRow(chapter: chapter)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

/// A single chapter row, supporting nested children via DisclosureGroup.
struct ChapterRow: View {
    let chapter: Chapter

    var body: some View {
        if chapter.isExpandable {
            DisclosureGroup {
                ForEach(chapter.children) { child in
                    ChapterRow(chapter: child)
                }
            } label: {
                chapterLabel
            }
        } else {
            chapterLabel
                .tag(chapter)
        }
    }

    private var chapterLabel: some View {
        Text(chapter.title)
            .font(.system(size: 13))
            .lineLimit(2)
            .padding(.vertical, 2)
    }
}
