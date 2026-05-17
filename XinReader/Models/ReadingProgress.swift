import Foundation

/// Stores the reading progress for a single book.
struct ReadingProgress: Codable {
    let bookID: UUID
    var scrollPercentage: Double     // 0.0 – 1.0 (primary restore mechanism)
    var currentChapterAnchor: String? // For sidebar highlight
    var currentPage: Int?            // PDF page index
    var lastReadDate: Date

    init(
        bookID: UUID,
        scrollPercentage: Double = 0.0,
        currentChapterAnchor: String? = nil,
        currentPage: Int? = nil,
        lastReadDate: Date = Date()
    ) {
        self.bookID = bookID
        self.scrollPercentage = scrollPercentage
        self.currentChapterAnchor = currentChapterAnchor
        self.currentPage = currentPage
        self.lastReadDate = lastReadDate
    }
}
