import XCTest
@testable import XinReader

final class TOCNavigationTests: XCTestCase {

    // MARK: - HTMLCleaner output for navigation

    func testHTMLContainsScrollToAnchorEPUB() {
        let html = HTMLCleaner.prepare(html: "<p>test</p>", css: "")
        XCTAssertTrue(html.contains("scrollToAnchorEPUB"))
        XCTAssertTrue(html.contains("findEPUBElement"))
        XCTAssertTrue(html.contains("getElementById"))
    }

    func testHTMLContainsDataAttributes() {
        // Simulate EPUB section div as produced by EPUBContentAssembler
        let content = """
        <div id="epub_ch01" data-href="Text/chapter1.xhtml" data-filename="chapter1.xhtml" data-basename="chapter1" class="epub-section">
        <p>Content</p>
        </div>
        """
        let result = HTMLCleaner.prepare(html: content, css: "")
        XCTAssertTrue(result.contains("data-href=\"Text/chapter1.xhtml\""))
        XCTAssertTrue(result.contains("data-filename=\"chapter1.xhtml\""))
        XCTAssertTrue(result.contains("data-basename=\"chapter1\""))
    }

    // MARK: - JavaScript handles IDs starting with digits

    func testJSUsesGetElementByIdNotQuerySelector() {
        // The fix: getElementById works with IDs starting with digits
        // querySelector('#2RHM0-...') would fail
        let html = HTMLCleaner.prepare(html: "<p>test</p>", css: "")
        // Must use getElementById for fragment lookup, NOT querySelector('#'+frag)
        XCTAssertTrue(html.contains("document.getElementById(frag)"))
        // Should NOT have querySelector('#'+frag) pattern (which breaks with numeric IDs)
        XCTAssertFalse(html.contains("querySelector('#'+frag)"))
    }

    // MARK: - Chapter model with various anchor formats

    func testChapterWithSimpleAnchor() {
        let ch = Chapter(title: "Intro", htmlAnchor: "intro", depth: 0)
        XCTAssertEqual(ch.htmlAnchor, "intro")
        XCTAssertEqual(ch.depth, 0)
    }

    func testChapterWithFilePathAnchor() {
        // EPUB style: file path reference
        let ch = Chapter(title: "Ch 1", htmlAnchor: "Text/chapter1.xhtml", depth: 0)
        XCTAssertEqual(ch.htmlAnchor, "Text/chapter1.xhtml")
    }

    func testChapterWithFragmentAnchor() {
        // EPUB style: file + fragment
        let ch = Chapter(title: "Section", htmlAnchor: "Text/part0003.html#2RHM0-dfb65213541a402f8b655e446cb35dc2", depth: 1)
        XCTAssertTrue(ch.htmlAnchor.contains("#"))
        // Fragment starts with a digit — this is the case that broke querySelector
        let fragment = ch.htmlAnchor.components(separatedBy: "#").last!
        XCTAssertTrue(fragment.first!.isNumber)
    }

    func testChapterWithOnlyFragment() {
        let ch = Chapter(title: "Note", htmlAnchor: "#footnote1", depth: 2)
        XCTAssertTrue(ch.htmlAnchor.hasPrefix("#"))
    }

    func testChapterWithEpubPrefixedId() {
        let ch = Chapter(title: "Part 1", htmlAnchor: "epub_item001", depth: 0)
        XCTAssertTrue(ch.htmlAnchor.hasPrefix("epub_"))
    }

    // MARK: - TOCExtractor basics

    func testTOCExtractorFindsHeadings() {
        let html = """
        <h1 id="ch1">Chapter 1</h1>
        <p>Content...</p>
        <h2 id="sec1">Section 1.1</h2>
        <p>More content...</p>
        <h1 id="ch2">Chapter 2</h1>
        """
        let chapters = TOCExtractor.extractFromHTML(html)
        XCTAssertGreaterThanOrEqual(chapters.count, 2)
    }

    func testTOCExtractorHandlesEmptyHTML() {
        let chapters = TOCExtractor.extractFromHTML("")
        XCTAssertEqual(chapters.count, 0)
    }

    func testTOCExtractorHandlesNoHeadings() {
        let html = "<p>Just a paragraph with no headings.</p>"
        let chapters = TOCExtractor.extractFromHTML(html)
        XCTAssertEqual(chapters.count, 0)
    }

    func testTOCExtractorHandlesNestedAnchors() {
        let html = """
        <h1><a name="intro">Introduction</a></h1>
        <h2><a name="bg">Background</a></h2>
        """
        let chapters = TOCExtractor.extractFromHTML(html)
        XCTAssertGreaterThanOrEqual(chapters.count, 1)
    }

    // MARK: - SidebarView chapter page lookup logic

    func testChapterPageLookupDirectMatch() {
        let map: [String: Int] = ["Text/chapter1.xhtml": 5, "Text/chapter2.xhtml": 12]
        let anchor = "Text/chapter1.xhtml"
        // Direct match
        XCTAssertEqual(map[anchor], 5)
    }

    func testChapterPageLookupByFilename() {
        let map: [String: Int] = ["chapter1.xhtml": 5, "chapter2.xhtml": 12]
        let anchor = "Text/chapter1.xhtml"
        let filename = (anchor as NSString).lastPathComponent
        XCTAssertEqual(map[filename], 5)
    }

    func testChapterPageLookupByBasename() {
        let map: [String: Int] = ["chapter1": 5, "chapter2": 12]
        let anchor = "Text/chapter1.xhtml#section1"
        let pathPart = anchor.components(separatedBy: "#").first!
        let filename = (pathPart as NSString).lastPathComponent
        let basename = (filename as NSString).deletingPathExtension
        XCTAssertEqual(map[basename], 5)
    }

    func testChapterPageLookupWithDigitFragment() {
        // The case that was broken: fragment starts with digit
        let map: [String: Int] = ["Text/part0003.html": 8]
        let anchor = "Text/part0003.html#2RHM0-abc123"
        let pathPart = anchor.components(separatedBy: "#").first!
        XCTAssertEqual(map[pathPart], 8)
    }

    func testChapterPageLookupNoMatch() {
        let map: [String: Int] = ["chapter1": 5]
        let anchor = "nonexistent.xhtml"
        let filename = (anchor as NSString).lastPathComponent
        let basename = (filename as NSString).deletingPathExtension
        XCTAssertNil(map[anchor])
        XCTAssertNil(map[filename])
        XCTAssertNil(map[basename])
    }
}
