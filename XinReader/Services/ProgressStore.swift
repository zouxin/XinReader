import Foundation

/// Manages per-book reading progress persistence using JSON files.
/// Storage location: ~/Library/Application Support/XinReader/progress/
final class ProgressStore {
    private let baseURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        baseURL = appSupport
            .appendingPathComponent("XinReader", isDirectory: true)
            .appendingPathComponent("progress", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
    }

    /// Load reading progress for a specific book.
    func load(for bookID: UUID) -> ReadingProgress? {
        let url = fileURL(for: bookID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ReadingProgress.self, from: data)
    }

    /// Save reading progress for a book.
    func save(_ progress: ReadingProgress) {
        let url = fileURL(for: progress.bookID)
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Delete reading progress for a book.
    func delete(for bookID: UUID) {
        let url = fileURL(for: bookID)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func fileURL(for bookID: UUID) -> URL {
        baseURL.appendingPathComponent("\(bookID.uuidString).json")
    }
}
