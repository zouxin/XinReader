import XCTest
@testable import XinReader

final class HTMLCleanerTests: XCTestCase {

    func testPrepareWrapsInTemplate() {
        let html = "<p>Hello World</p>"
        let css = "body { color: red; }"
        let result = HTMLCleaner.prepare(html: html, css: css)
        XCTAssertTrue(result.contains("<!DOCTYPE html>"))
        XCTAssertTrue(result.contains("<p>Hello World</p>"))
        XCTAssertTrue(result.contains("body { color: red; }"))
        XCTAssertTrue(result.contains("id=\"book-content\""))
    }

    func testRewritesMobiImageTags() {
        let html = #"<img recindex="00003" />"#
        let result = HTMLCleaner.prepare(html: html, css: "")
        XCTAssertTrue(result.contains("bookimage://recindex:00003"))
        XCTAssertFalse(result.contains("recindex=\"00003\""))
    }

    func testRewritesKindleEmbed() {
        let html = #"<img src="kindle:embed:00012">"#
        let result = HTMLCleaner.prepare(html: html, css: "")
        XCTAssertTrue(result.contains("bookimage://recindex:00012"))
    }

    func testStripsScriptTags() {
        let html = "<p>text</p><script>alert('xss')</script><p>more</p>"
        let result = HTMLCleaner.prepare(html: html, css: "")
        XCTAssertFalse(result.contains("alert('xss')"))
        XCTAssertTrue(result.contains("<p>text</p>"))
        XCTAssertTrue(result.contains("<p>more</p>"))
    }

    func testFixesBrTagsForMobiContent() {
        // MOBI content triggers full cleanup (contains "recindex")
        let html = "<p>line1<br>line2</p><img recindex=\"1\">"
        let result = HTMLCleaner.prepare(html: html, css: "")
        XCTAssertTrue(result.contains("<br/>"))
    }

    func testEPUBContentSkipsMobiCleanup() {
        // EPUB content (no recindex/kindle/mbp markers) takes fast path
        let html = "<p>line1<br>line2</p>"
        let result = HTMLCleaner.prepare(html: html, css: "")
        // Should still produce valid output, just not fix <br>
        XCTAssertTrue(result.contains("<!DOCTYPE html>"))
        XCTAssertTrue(result.contains("<p>line1"))
    }

    func testContainsPaginationJS() {
        let result = HTMLCleaner.prepare(html: "<p>test</p>", css: "")
        XCTAssertTrue(result.contains("scrollToAnchorEPUB"))
        XCTAssertTrue(result.contains("recalc"))
        XCTAssertTrue(result.contains("goTo"))
    }
}
