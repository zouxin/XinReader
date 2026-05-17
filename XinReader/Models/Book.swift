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
    var tags: [String]

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
        tags: [String] = [],
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
        self.tags = tags
        self.addedDate = addedDate
        self.lastOpenedDate = lastOpenedDate
    }

    // Custom Decodable: tolerate missing keys for fields added after initial release
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        securityBookmark = try container.decodeIfPresent(Data.self, forKey: .securityBookmark)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        coverImageData = try container.decodeIfPresent(Data.self, forKey: .coverImageData)
        format = try container.decodeIfPresent(BookFormat.self, forKey: .format)
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        addedDate = (try? container.decode(Date.self, forKey: .addedDate)) ?? Date()
        lastOpenedDate = try container.decodeIfPresent(Date.self, forKey: .lastOpenedDate)
    }
}
