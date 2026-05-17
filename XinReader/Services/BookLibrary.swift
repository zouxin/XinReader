import Foundation

/// Manages the book library (catalog of all opened books) and tags.
/// Storage: ~/Library/Application Support/XinReader/library.json, tags.json
final class BookLibrary: ObservableObject {
    @Published var books: [Book] = []
    @Published var tags: [String] = []

    private let libraryURL: URL
    private let tagsURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let baseDir = appSupport.appendingPathComponent("XinReader", isDirectory: true)

        // Migrate from old MobiReader path if exists
        let oldDir = appSupport.appendingPathComponent("MobiReader", isDirectory: true)
        if FileManager.default.fileExists(atPath: oldDir.path) &&
           !FileManager.default.fileExists(atPath: baseDir.path) {
            try? FileManager.default.moveItem(at: oldDir, to: baseDir)
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: baseDir,
            withIntermediateDirectories: true
        )

        libraryURL = baseDir.appendingPathComponent("library.json")
        tagsURL = baseDir.appendingPathComponent("tags.json")
        loadBooks()
        loadTags()
    }

    /// Testable initializer with custom base directory.
    init(baseDirectory: URL) {
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        libraryURL = baseDirectory.appendingPathComponent("library.json")
        tagsURL = baseDirectory.appendingPathComponent("tags.json")
        loadBooks()
        loadTags()
    }

    // MARK: - Book Methods

    /// Add a new book or update an existing one (by file URL).
    func addOrUpdate(_ book: Book) {
        if let index = books.firstIndex(where: { $0.fileURL == book.fileURL }) {
            books[index].lastOpenedDate = Date()
            books[index].title = book.title
            books[index].author = book.author
            if let cover = book.coverImageData {
                books[index].coverImageData = cover
            }
        } else {
            books.append(book)
        }
        saveBooks()
    }

    /// Remove a book from the library.
    func remove(_ book: Book) {
        books.removeAll { $0.id == book.id }
        saveBooks()
    }

    /// Get books sorted by last opened date (most recent first).
    var recentBooks: [Book] {
        books.sorted { ($0.lastOpenedDate ?? $0.addedDate) > ($1.lastOpenedDate ?? $1.addedDate) }
    }

    /// Get books filtered by tag.
    func books(withTag tag: String) -> [Book] {
        let filtered = books.filter { $0.tags.contains(tag) }
        return filtered.sorted { ($0.lastOpenedDate ?? $0.addedDate) > ($1.lastOpenedDate ?? $1.addedDate) }
    }

    /// Get books that have no tags assigned.
    var uncategorizedBooks: [Book] {
        let filtered = books.filter { $0.tags.isEmpty }
        return filtered.sorted { ($0.lastOpenedDate ?? $0.addedDate) > ($1.lastOpenedDate ?? $1.addedDate) }
    }

    /// Set tags for a specific book.
    func setTags(for bookID: UUID, tags: [String]) {
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].tags = tags
            saveBooks()
        }
    }

    /// Add a single tag to a book.
    func addTag(_ tag: String, to bookID: UUID) {
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            if !books[index].tags.contains(tag) {
                books[index].tags.append(tag)
                saveBooks()
            }
        }
    }

    /// Remove a single tag from a book.
    func removeTag(_ tag: String, from bookID: UUID) {
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].tags.removeAll { $0 == tag }
            saveBooks()
        }
    }

    // MARK: - Tag Management

    /// Add a new tag to the tag list.
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        saveTags()
    }

    /// Remove a tag from the tag list and all books.
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        // Also remove from all books
        for i in books.indices {
            books[i].tags.removeAll { $0 == tag }
        }
        saveTags()
        saveBooks()
    }

    /// Rename a tag.
    func renameTag(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        if let index = tags.firstIndex(of: oldName) {
            tags[index] = trimmed
        }
        for i in books.indices {
            if let tagIdx = books[i].tags.firstIndex(of: oldName) {
                books[i].tags[tagIdx] = trimmed
            }
        }
        saveTags()
        saveBooks()
    }

    // MARK: - Persistence

    private func loadBooks() {
        guard let data = try? Data(contentsOf: libraryURL) else { return }
        if let decoded = try? JSONDecoder().decode([Book].self, from: data) {
            self.books = decoded
        }
    }

    private func saveBooks() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    private func loadTags() {
        guard let data = try? Data(contentsOf: tagsURL) else { return }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.tags = decoded
        }
    }

    private func saveTags() {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        try? data.write(to: tagsURL, options: .atomic)
    }
}
