import XCTest
@testable import XinReader

final class ReaderStyleSheetTests: XCTestCase {

    func testGenerateContainsFontFamily() {
        let settings = ReaderSettings(
            fontFamily: "Menlo",
            fontSize: 20,
            lineSpacing: 1.8,
            theme: .dark
        )
        let css = ReaderStyleSheet.generate(from: settings)
        XCTAssertTrue(css.contains("'Menlo'"))
        XCTAssertTrue(css.contains("20px"))
        XCTAssertTrue(css.contains("1.8"))
    }

    func testGenerateContainsThemeColors() {
        let settings = ReaderSettings(
            fontFamily: "Georgia",
            fontSize: 18,
            lineSpacing: 1.6,
            theme: .sepia
        )
        let css = ReaderStyleSheet.generate(from: settings)
        XCTAssertTrue(css.contains("#F5E6C8"))  // sepia background
        XCTAssertTrue(css.contains("#5B4636"))  // sepia text
    }

    func testGenerateContainsColumnLayout() {
        let css = ReaderStyleSheet.generate(from: .default)
        XCTAssertTrue(css.contains("column-count: 2"))
        XCTAssertTrue(css.contains("column-gap"))
    }
}
