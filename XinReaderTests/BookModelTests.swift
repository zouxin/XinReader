import XCTest
@testable import XinReader

final class BookModelTests: XCTestCase {

    func testBookCreation() {
        let book = Book(
            fileURL: URL(fileURLWithPath: "/tmp/test.epub"),
            title: "Test Book",
            author: "Author"
        )
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Author")
        XCTAssertTrue(book.tags.isEmpty)
        XCTAssertNil(book.format)
    }

    func testBookCodableWithTags() throws {
        let book = Book(
            fileURL: URL(fileURLWithPath: "/tmp/test.mobi"),
            title: "Tagged",
            author: "Writer",
            format: .mobi,
            tags: ["fiction", "sci-fi"]
        )
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        XCTAssertEqual(decoded.title, "Tagged")
        XCTAssertEqual(decoded.tags, ["fiction", "sci-fi"])
        XCTAssertEqual(decoded.format, .mobi)
    }

    func testBookDecodableWithoutTagsField() throws {
        // Simulate old JSON without tags field
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789ABC",
            "fileURL": "file:///tmp/old.epub",
            "title": "Old Book",
            "author": "Old Author",
            "addedDate": 700000000
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Book.self, from: json)
        XCTAssertEqual(decoded.title, "Old Book")
        XCTAssertEqual(decoded.tags, [])  // Should default to empty, not crash
        XCTAssertNil(decoded.format)
    }

    func testChapterCreation() {
        let child = Chapter(title: "Section 1.1", htmlAnchor: "sec1_1", depth: 1)
        let parent = Chapter(
            title: "Chapter 1",
            htmlAnchor: "ch1",
            children: [child],
            depth: 0
        )
        XCTAssertTrue(parent.isExpandable)
        XCTAssertFalse(child.isExpandable)
        XCTAssertEqual(parent.children.count, 1)
    }

    func testReadingProgressCodable() throws {
        let progress = ReadingProgress(
            bookID: UUID(),
            scrollPercentage: 0.75,
            currentChapterAnchor: "ch5",
            currentPage: 42
        )
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(ReadingProgress.self, from: data)
        XCTAssertEqual(decoded.scrollPercentage, 0.75)
        XCTAssertEqual(decoded.currentChapterAnchor, "ch5")
        XCTAssertEqual(decoded.currentPage, 42)
    }

    func testBookFormatFromExtension() {
        XCTAssertEqual(BookFormat(fromExtension: "epub"), .epub)
        XCTAssertEqual(BookFormat(fromExtension: "EPUB"), .epub)
        XCTAssertEqual(BookFormat(fromExtension: "mobi"), .mobi)
        XCTAssertEqual(BookFormat(fromExtension: "prc"), .mobi)
        XCTAssertEqual(BookFormat(fromExtension: "pdf"), .pdf)
        XCTAssertNil(BookFormat(fromExtension: "txt"))
    }
}
