import Foundation

/// Represents a book's metadata as stored in the library.
struct Book: Identifiable, Codable {
    let id: UUID
    let fileURL: URL
    var securityBookmark: Data?

    // Metadata
    var title: String
    var author: String
    var language: String?
    var publisher: String?
    var coverImageData: Data?
    var format: BookFormat?

    // Timestamps
    var addedDate: Date
    var lastOpenedDate: Date?

    init(
        id: UUID = UUID(),
        fileURL: URL,
        securityBookmark: Data? = nil,
        title: String,
        author: String,
        language: String? = nil,
        publisher: String? = nil,
        coverImageData: Data? = nil,
        format: BookFormat? = nil,
        addedDate: Date = Date(),
        lastOpenedDate: Date? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.securityBookmark = securityBookmark
        self.title = title
        self.author = author
        self.language = language
        self.publisher = publisher
        self.coverImageData = coverImageData
        self.format = format
        self.addedDate = addedDate
        self.lastOpenedDate = lastOpenedDate
    }
}
