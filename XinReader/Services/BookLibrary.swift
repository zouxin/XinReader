import Foundation

/// Manages the book library (catalog of all opened books).
/// Storage location: ~/Library/Application Support/XinReader/library.json
final class BookLibrary: ObservableObject {
    @Published var books: [Book] = []

    private let fileURL: URL

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

        fileURL = baseDir.appendingPathComponent("library.json")
        load()
    }

    // MARK: - Public Methods

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
        save()
    }

    /// Remove a book from the library.
    func remove(_ book: Book) {
        books.removeAll { $0.id == book.id }
        save()
    }

    /// Get books sorted by last opened date (most recent first).
    var recentBooks: [Book] {
        books.sorted { ($0.lastOpenedDate ?? $0.addedDate) > ($1.lastOpenedDate ?? $1.addedDate) }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Book].self, from: data) {
            self.books = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
