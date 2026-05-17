import SwiftUI

/// Sidebar view displaying the book's table of contents as a navigable tree.
struct SidebarView: View {
    let chapters: [Chapter]
    @Binding var selectedChapter: Chapter?
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with progress
            HStack {
                Image(systemName: "list.bullet")
                Text("目录")
                    .font(.headline)
                Spacer()
                // Reading progress
                Text(progressText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progressFraction, height: 2)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 16)

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

    private var progressFraction: CGFloat {
        guard appState.totalPageCount > 1 else { return 0 }
        return CGFloat(appState.currentPageIndex) / CGFloat(appState.totalPageCount - 1)
    }

    private var progressText: String {
        let percent = Int(progressFraction * 100)
        return "\(appState.currentPageIndex + 1)/\(appState.totalPageCount)  \(percent)%"
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
