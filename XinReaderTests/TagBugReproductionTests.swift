import XCTest
@testable import XinReader

/// Tests that reproduce the exact user-reported bug:
/// "在历史tag里添加的书，返回书库发现在未分类里面"
final class TagBugReproductionTests: XCTestCase {

    private var library: BookLibrary!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("XinReaderTagBug_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        library = BookLibrary(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Full reproduction of the exact user flow:
    /// 1. Add book to library
    /// 2. Create "历史" tag
    /// 3. Assign "历史" tag to the book
    /// 4. Verify book shows under "历史" filter
    /// 5. Simulate openBook (what happens when user clicks to read)
    /// 6. Verify book is still tagged after "returning to library"
    func testExactUserFlow_TagBookOpenReturnCheckTag() {
        // Step 1: Add a book (simulating first time open)
        let fileURL = URL(fileURLWithPath: "/Users/test/电子书/安史之乱.epub")
        let book = Book(
            fileURL: fileURL,
            title: "安史之乱",
            author: "Author",
            format: .epub
        )
        library.addOrUpdate(book)
        let bookID = library.books.first!.id

        // Step 2: Create tag
        library.addTag("历史")

        // Step 3: Assign tag
        library.addTag("历史", to: bookID)

        // Step 4: Verify
        XCTAssertEqual(library.books(withTag: "历史").count, 1, "Book should be under 历史")
        XCTAssertEqual(library.uncategorizedBooks.count, 0, "No uncategorized books")

        // Step 5: Simulate what AppState.openBook does — creates a NEW Book object
        let bookMetaFromParser = Book(
            fileURL: fileURL,    // same URL
            title: "安史之乱",
            author: "Author",
            format: .epub
            // NOTE: tags defaults to [] — this is what openBook creates
        )
        XCTAssertEqual(bookMetaFromParser.tags, [], "New Book from parser has empty tags")

        library.addOrUpdate(bookMetaFromParser)

        // Step 6: THE CRITICAL CHECK — after "returning to library"
        print("Books after reopen: \(library.books.count)")
        for b in library.books {
            print("  title=\(b.title)  tags=\(b.tags)")
        }

        XCTAssertEqual(library.books.count, 1, "Should still be 1 book, not duplicated")
        XCTAssertEqual(library.books.first!.tags, ["历史"], "Tags must be preserved!")
        XCTAssertEqual(library.books(withTag: "历史").count, 1, "Book must still show under 历史")
        XCTAssertEqual(library.uncategorizedBooks.count, 0, "Must NOT show as uncategorized!")
    }

    /// Same test but with persistence: save to disk, reload, verify
    func testTagSurvivesReopenAndPersistence() {
        let fileURL = URL(fileURLWithPath: "/Users/test/电子书/县乡中国.epub")
        let book = Book(fileURL: fileURL, title: "县乡中国", author: "杨华", format: .epub)
        library.addOrUpdate(book)
        let bookID = library.books.first!.id
        library.addTag("社会")
        library.addTag("社会", to: bookID)

        // Reopen (simulate openBook)
        let reopened = Book(fileURL: fileURL, title: "县乡中国", author: "杨华", format: .epub)
        library.addOrUpdate(reopened)

        // Reload from disk
        let library2 = BookLibrary(baseDirectory: tempDir)

        print("After reload: \(library2.books.count) books")
        for b in library2.books {
            print("  title=\(b.title)  tags=\(b.tags)")
        }

        XCTAssertEqual(library2.books.count, 1)
        XCTAssertEqual(library2.books.first!.tags, ["社会"])
        XCTAssertEqual(library2.uncategorizedBooks.count, 0)
    }

    /// Test with the REAL library data format (as stored on disk)
    func testWithRealJSONFormat() throws {
        // Write JSON in the exact format that's on the user's disk
        let json = """
        [{"id":"3E74BEC9-FA38-4E08-890C-6FC91CA68873","fileURL":"file:///Users/davidzou/Library/Mobile%20Documents/com~apple~CloudDocs/%E7%94%B5%E5%AD%90%E4%B9%A6/%E5%8E%86%E5%8F%B2/test.epub","title":"安史之乱","author":"Author","tags":["历史"],"addedDate":700000000,"lastOpenedDate":700000000}]
        """.data(using: .utf8)!
        try json.write(to: tempDir.appendingPathComponent("library.json"))

        let tagsJson = "[\"历史\",\"小说\",\"社会\"]".data(using: .utf8)!
        try tagsJson.write(to: tempDir.appendingPathComponent("tags.json"))

        // Load
        let lib = BookLibrary(baseDirectory: tempDir)
        XCTAssertEqual(lib.books.count, 1)
        XCTAssertEqual(lib.books.first!.tags, ["历史"])

        // Now simulate openBook with the SAME percent-encoded URL
        let url = URL(string: "file:///Users/davidzou/Library/Mobile%20Documents/com~apple~CloudDocs/%E7%94%B5%E5%AD%90%E4%B9%A6/%E5%8E%86%E5%8F%B2/test.epub")!
        let reopened = Book(fileURL: url, title: "安史之乱 v2", author: "Author")
        lib.addOrUpdate(reopened)

        print("After addOrUpdate with percent-encoded URL:")
        print("  count=\(lib.books.count)  tags=\(lib.books.first!.tags)")

        XCTAssertEqual(lib.books.count, 1, "Must not duplicate")
        XCTAssertEqual(lib.books.first!.tags, ["历史"], "Tags must survive")
        XCTAssertEqual(lib.books.first!.title, "安史之乱 v2", "Title should update")

        // Now try with a NON-percent-encoded URL (what fileImporter might return)
        let rawURL = URL(fileURLWithPath: "/Users/davidzou/Library/Mobile Documents/com~apple~CloudDocs/电子书/历史/test.epub")
        let reopened2 = Book(fileURL: rawURL, title: "安史之乱 v3", author: "Author")
        lib.addOrUpdate(reopened2)

        print("After addOrUpdate with raw URL:")
        print("  count=\(lib.books.count)")
        for b in lib.books {
            print("    title=\(b.title)  tags=\(b.tags)  url=\(b.fileURL)")
        }

        // This is the key test — does the URL mismatch cause a duplicate?
        if lib.books.count > 1 {
            print("  BUG: Duplicate created!")
            print("  URL1: \(lib.books[0].fileURL)")
            print("  URL2: \(lib.books[1].fileURL)")
            print("  Path1: \(lib.books[0].fileURL.standardizedFileURL.path)")
            print("  Path2: \(lib.books[1].fileURL.standardizedFileURL.path)")
        }

        // If this fails, the URL matching is still broken
        XCTAssertEqual(lib.books.count, 1, "URL encoding mismatch must not create duplicate")
    }
}
