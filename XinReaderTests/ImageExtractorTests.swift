import XCTest
@testable import XinReader

final class ImageExtractorTests: XCTestCase {

    func testIsImageDataJPEG() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        XCTAssertTrue(ImageExtractor.isImageData(jpeg))
    }

    func testIsImageDataPNG() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D])
        XCTAssertTrue(ImageExtractor.isImageData(png))
    }

    func testIsImageDataGIF() {
        let gif = Data([0x47, 0x49, 0x46, 0x38, 0x39])
        XCTAssertTrue(ImageExtractor.isImageData(gif))
    }

    func testIsImageDataBMP() {
        let bmp = Data([0x42, 0x4D, 0x00, 0x00, 0x00])
        XCTAssertTrue(ImageExtractor.isImageData(bmp))
    }

    func testIsImageDataInvalid() {
        let text = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])
        XCTAssertFalse(ImageExtractor.isImageData(text))
    }

    func testIsImageDataTooShort() {
        let short = Data([0xFF, 0xD8])
        XCTAssertFalse(ImageExtractor.isImageData(short))
    }

    func testMimeTypeJPEG() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        XCTAssertEqual(ImageExtractor.mimeType(for: jpeg), "image/jpeg")
    }

    func testMimeTypePNG() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D])
        XCTAssertEqual(ImageExtractor.mimeType(for: png), "image/png")
    }

    func testMimeTypeGIF() {
        let gif = Data([0x47, 0x49, 0x46, 0x38, 0x39])
        XCTAssertEqual(ImageExtractor.mimeType(for: gif), "image/gif")
    }

    func testMimeTypeUnknown() {
        let unknown = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertEqual(ImageExtractor.mimeType(for: unknown), "application/octet-stream")
    }
}
