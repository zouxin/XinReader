import XCTest
@testable import XinReader

final class BookLibraryTests: XCTestCase {

    private var library: BookLibrary!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        // Use a temp directory to avoid polluting the real library
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("XinReaderTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        library = BookLibrary(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Book CRUD

    func testAddBook() {
        let book = makeBook(title: "Book 1")
        library.addOrUpdate(book)
        XCTAssertEqual(library.books.count, 1)
        XCTAssertEqual(library.books.first?.title, "Book 1")
    }

    func testAddMultipleBooks() {
        library.addOrUpdate(makeBook(title: "A", path: "/a.epub"))
        library.addOrUpdate(makeBook(title: "B", path: "/b.epub"))
        library.addOrUpdate(makeBook(title: "C", path: "/c.epub"))
        XCTAssertEqual(library.books.count, 3)
    }

    func testUpdateExistingBook() {
        let book = makeBook(title: "Original", path: "/test.epub")
        library.addOrUpdate(book)
        XCTAssertEqual(library.books.first?.title, "Original")

        // Update same file URL with new title
        var updated = makeBook(title: "Updated", path: "/test.epub")
        updated = Book(
            fileURL: URL(fileURLWithPath: "/test.epub"),
            title: "Updated",
            author: "Author"
        )
        library.addOrUpdate(updated)
        XCTAssertEqual(library.books.count, 1) // Should not duplicate
        XCTAssertEqual(library.books.first?.title, "Updated")
    }

    /// Regression: opening a tagged book must not clear its tags.
    /// This simulates what AppState.openBook() does — creates a new Book
    /// with empty tags and calls addOrUpdate. Tags must survive.
    func testAddOrUpdatePreservesExistingTags() {
        let book = makeBook(title: "MyBook", path: "/mybook.epub")
        library.addOrUpdate(book)
        library.addTag("历史")
        library.addTag("历史", to: book.id)
        XCTAssertEqual(library.books.first?.tags, ["历史"])

        // Simulate re-opening the book (AppState creates a new Book with empty tags)
        let reopened = Book(
            fileURL: URL(fileURLWithPath: "/mybook.epub"),
            title: "MyBook",
            author: "Test Author"
            // tags defaults to [] — this is the bug scenario
        )
        library.addOrUpdate(reopened)

        // Tags must still be there
        XCTAssertEqual(library.books.count, 1)
        XCTAssertEqual(library.books.first?.tags, ["历史"])
    }

    /// Ensure tags survive multiple rounds of addOrUpdate
    func testAddOrUpdatePreservesTagsMultipleReopens() {
        let book = makeBook(title: "Book", path: "/book.epub")
        library.addOrUpdate(book)
        library.addTag("小说")
        library.addTag("小说", to: book.id)
        library.addTag("推荐")
        library.addTag("推荐", to: book.id)

        // Reopen 3 times
        for i in 1...3 {
            let reopened = Book(
                fileURL: URL(fileURLWithPath: "/book.epub"),
                title: "Book v\(i)",
                author: "Author"
            )
            library.addOrUpdate(reopened)
        }

        XCTAssertEqual(library.books.count, 1)
        XCTAssertEqual(library.books.first?.title, "Book v3") // title updated
        XCTAssertEqual(Set(library.books.first?.tags ?? []), Set(["小说", "推荐"])) // tags preserved
    }

    /// Tags survive persistence after addOrUpdate
    func testTagsSurvivePersistenceAfterReopen() {
        let book = makeBook(title: "PBook", path: "/pbook.epub")
        library.addOrUpdate(book)
        library.addTag("Tech")
        library.addTag("Tech", to: book.id)

        // Simulate reopen
        let reopened = Book(
            fileURL: URL(fileURLWithPath: "/pbook.epub"),
            title: "PBook",
            author: "Author"
        )
        library.addOrUpdate(reopened)

        // Load from disk
        let library2 = BookLibrary(baseDirectory: tempDir)
        XCTAssertEqual(library2.books.first?.tags, ["Tech"])
    }

    func testRemoveBook() {
        let book = makeBook(title: "ToRemove")
        library.addOrUpdate(book)
        XCTAssertEqual(library.books.count, 1)

        library.remove(book)
        XCTAssertEqual(library.books.count, 0)
    }

    func testRemoveNonexistentBookDoesNothing() {
        library.addOrUpdate(makeBook(title: "Keep"))
        let other = makeBook(title: "Other")
        library.remove(other)
        XCTAssertEqual(library.books.count, 1)
    }

    func testRecentBooksOrder() {
        var a = makeBook(title: "A", path: "/a.epub")
        a = Book(fileURL: URL(fileURLWithPath: "/a.epub"), title: "A", author: "X",
                 addedDate: Date(timeIntervalSince1970: 1000), lastOpenedDate: Date(timeIntervalSince1970: 2000))
        var b = makeBook(title: "B", path: "/b.epub")
        b = Book(fileURL: URL(fileURLWithPath: "/b.epub"), title: "B", author: "X",
                 addedDate: Date(timeIntervalSince1970: 1000), lastOpenedDate: Date(timeIntervalSince1970: 3000))
        library.addOrUpdate(a)
        library.addOrUpdate(b)
        XCTAssertEqual(library.recentBooks.first?.title, "B") // More recent
    }

    // MARK: - Tag Management

    func testAddTag() {
        library.addTag("Fiction")
        XCTAssertEqual(library.tags, ["Fiction"])
    }

    func testAddDuplicateTag() {
        library.addTag("Fiction")
        library.addTag("Fiction")
        XCTAssertEqual(library.tags.count, 1)
    }

    func testAddEmptyTag() {
        library.addTag("")
        library.addTag("   ")
        XCTAssertEqual(library.tags.count, 0)
    }

    func testRemoveTag() {
        library.addTag("Fiction")
        library.addTag("Sci-Fi")
        library.removeTag("Fiction")
        XCTAssertEqual(library.tags, ["Sci-Fi"])
    }

    func testRemoveTagAlsoRemovesFromBooks() {
        let book = makeBook(title: "Tagged")
        library.addOrUpdate(book)
        library.addTag("Fiction")
        library.addTag(  "Fiction", to: book.id)
        XCTAssertEqual(library.books.first?.tags, ["Fiction"])

        library.removeTag("Fiction")
        XCTAssertEqual(library.books.first?.tags, [])
    }

    func testRenameTag() {
        library.addTag("Sci-Fi")
        let book = makeBook(title: "Book")
        library.addOrUpdate(book)
        library.addTag("Sci-Fi", to: book.id)

        library.renameTag("Sci-Fi", to: "Science Fiction")
        XCTAssertEqual(library.tags, ["Science Fiction"])
        XCTAssertEqual(library.books.first?.tags, ["Science Fiction"])
    }

    func testRenameTagToDuplicate() {
        library.addTag("A")
        library.addTag("B")
        library.renameTag("A", to: "B") // Should not allow
        XCTAssertTrue(library.tags.contains("A")) // A should still exist
    }

    // MARK: - Book Tag Assignment

    func testAddTagToBook() {
        let book = makeBook(title: "Book")
        library.addOrUpdate(book)
        library.addTag("History")
        library.addTag("History", to: book.id)
        XCTAssertEqual(library.books.first?.tags, ["History"])
    }

    func testAddDuplicateTagToBook() {
        let book = makeBook(title: "Book")
        library.addOrUpdate(book)
        library.addTag("History")
        library.addTag("History", to: book.id)
        library.addTag("History", to: book.id) // duplicate
        XCTAssertEqual(library.books.first?.tags, ["History"])
    }

    func testRemoveTagFromBook() {
        let book = makeBook(title: "Book")
        library.addOrUpdate(book)
        library.addTag("History")
        library.addTag("History", to: book.id)
        library.removeTag("History", from: book.id)
        XCTAssertEqual(library.books.first?.tags, [])
    }

    func testSetTagsForBook() {
        let book = makeBook(title: "Book")
        library.addOrUpdate(book)
        library.setTags(for: book.id, tags: ["A", "B", "C"])
        XCTAssertEqual(library.books.first?.tags, ["A", "B", "C"])

        library.setTags(for: book.id, tags: ["X"])
        XCTAssertEqual(library.books.first?.tags, ["X"])
    }

    // MARK: - Filtering

    func testBooksWithTag() {
        let a = makeBook(title: "A", path: "/a.epub")
        let b = makeBook(title: "B", path: "/b.epub")
        library.addOrUpdate(a)
        library.addOrUpdate(b)
        library.addTag("Fiction")
        library.addTag("Fiction", to: a.id)

        let filtered = library.books(withTag: "Fiction")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "A")
    }

    func testUncategorizedBooks() {
        let a = makeBook(title: "Tagged", path: "/a.epub")
        let b = makeBook(title: "Untagged", path: "/b.epub")
        library.addOrUpdate(a)
        library.addOrUpdate(b)
        library.addTag("Fiction")
        library.addTag("Fiction", to: a.id)

        let uncategorized = library.uncategorizedBooks
        XCTAssertEqual(uncategorized.count, 1)
        XCTAssertEqual(uncategorized.first?.title, "Untagged")
    }

    func testAllBooksIncludesTaggedAndUntagged() {
        let a = makeBook(title: "A", path: "/a.epub")
        let b = makeBook(title: "B", path: "/b.epub")
        library.addOrUpdate(a)
        library.addOrUpdate(b)
        library.addTag("X")
        library.addTag("X", to: a.id)

        XCTAssertEqual(library.recentBooks.count, 2)
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() {
        let book = makeBook(title: "Persisted", path: "/persisted.epub")
        library.addOrUpdate(book)
        library.addTag("Saved")
        library.addTag("Saved", to: book.id)

        // Create a new library instance reading from same directory
        let library2 = BookLibrary(baseDirectory: tempDir)
        XCTAssertEqual(library2.books.count, 1)
        XCTAssertEqual(library2.books.first?.title, "Persisted")
        XCTAssertEqual(library2.books.first?.tags, ["Saved"])
        XCTAssertEqual(library2.tags, ["Saved"])
    }

    // MARK: - Helpers

    private func makeBook(title: String, path: String = "/tmp/\(UUID().uuidString).epub") -> Book {
        Book(
            fileURL: URL(fileURLWithPath: path),
            title: title,
            author: "Test Author",
            format: .epub
        )
    }
}
