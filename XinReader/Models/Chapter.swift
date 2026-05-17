import Foundation

/// Represents a chapter/section in the book's table of contents.
/// Supports nested structure (tree) via children array.
struct Chapter: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let htmlAnchor: String        // Fragment ID or generated anchor name
    let sourceOffset: Int?        // Character offset in the HTML (for position tracking)
    let pageIndex: Int?           // PDF page index (nil for HTML-based formats)
    var children: [Chapter]       // Nested sub-chapters
    var depth: Int                // 0 = top-level (h1), 1 = sub (h2), 2 = sub-sub (h3)

    var isExpandable: Bool { !children.isEmpty }

    init(
        id: UUID = UUID(),
        title: String,
        htmlAnchor: String,
        sourceOffset: Int? = nil,
        children: [Chapter] = [],
        depth: Int = 0,
        pageIndex: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.htmlAnchor = htmlAnchor
        self.sourceOffset = sourceOffset
        self.pageIndex = pageIndex
        self.children = children
        self.depth = depth
    }

    // Hashable conformance (by id)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }
}
