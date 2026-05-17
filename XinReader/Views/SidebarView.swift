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
                        ChapterRow(
                            chapter: chapter,
                            chapterPageMap: appState.chapterPageMap,
                            totalPages: appState.totalPageCount
                        )
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
    let chapterPageMap: [String: Int]
    let totalPages: Int

    var body: some View {
        if chapter.isExpandable {
            DisclosureGroup {
                ForEach(chapter.children) { child in
                    ChapterRow(
                        chapter: child,
                        chapterPageMap: chapterPageMap,
                        totalPages: totalPages
                    )
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
        HStack {
            Text(chapter.title)
                .font(.system(size: 13))
                .lineLimit(2)
            Spacer()
            if let pageInfo = chapterPageInfo {
                Text(pageInfo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    /// Look up this chapter's page number from the map.
    /// Try htmlAnchor directly, then common epub_ prefixed variants.
    private var chapterPageInfo: String? {
        guard totalPages > 1 else { return nil }

        let page = findPage()
        guard let p = page else { return nil }

        let percent = Int(Double(p) / Double(totalPages - 1) * 100)
        return "p.\(p + 1) \(percent)%"
    }

    private func findPage() -> Int? {
        // Direct match on htmlAnchor
        if let p = chapterPageMap[chapter.htmlAnchor] { return p }

        // Try matching by filename/basename from the anchor
        let anchor = chapter.htmlAnchor
        let filename = (anchor as NSString).lastPathComponent
        let basename = (filename as NSString).deletingPathExtension

        // Scan map keys for match
        for (key, page) in chapterPageMap {
            let keyFile = (key as NSString).lastPathComponent
            let keyBase = (keyFile as NSString).deletingPathExtension
            if keyFile == filename || keyBase == basename {
                return page
            }
            // epub_ prefixed id
            if key.hasPrefix("epub_") && key.lowercased().contains(basename.lowercased()) {
                return page
            }
        }

        return nil
    }
}
