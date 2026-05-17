import XCTest
@testable import XinReader

final class ReaderSettingsTests: XCTestCase {

    func testDefaultSettings() {
        let settings = ReaderSettings.default
        XCTAssertEqual(settings.fontFamily, "Georgia")
        XCTAssertEqual(settings.fontSize, 18)
        XCTAssertEqual(settings.lineSpacing, 1.6)
        XCTAssertEqual(settings.theme, .light)
    }

    func testThemeColors() {
        XCTAssertEqual(ReaderSettings.ReaderTheme.light.backgroundColor, "#FFFFFF")
        XCTAssertEqual(ReaderSettings.ReaderTheme.dark.backgroundColor, "#1E1E1E")
        XCTAssertEqual(ReaderSettings.ReaderTheme.sepia.backgroundColor, "#F5E6C8")
        XCTAssertEqual(ReaderSettings.ReaderTheme.eyeProtection.backgroundColor, "#C7EDCC")
    }

    func testThemeDisplayNames() {
        XCTAssertEqual(ReaderSettings.ReaderTheme.light.displayName, "浅色")
        XCTAssertEqual(ReaderSettings.ReaderTheme.dark.displayName, "深色")
        XCTAssertEqual(ReaderSettings.ReaderTheme.sepia.displayName, "暖纸")
        XCTAssertEqual(ReaderSettings.ReaderTheme.eyeProtection.displayName, "护眼")
    }

    func testSettingsEquality() {
        var a = ReaderSettings.default
        var b = ReaderSettings.default
        XCTAssertEqual(a, b)

        a.fontSize = 20
        XCTAssertNotEqual(a, b)

        b.fontSize = 20
        XCTAssertEqual(a, b)
    }

    func testSettingsCodable() throws {
        let settings = ReaderSettings(
            fontFamily: "Menlo",
            fontSize: 24,
            lineSpacing: 2.0,
            theme: .dark
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ReaderSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }
}
