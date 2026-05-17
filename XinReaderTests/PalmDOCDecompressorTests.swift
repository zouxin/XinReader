import XCTest
@testable import XinReader

final class PalmDOCDecompressorTests: XCTestCase {

    func testLiteralBytes() {
        // Bytes 0x09-0x7F are literal (printable ASCII)
        let input = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(String(data: output, encoding: .ascii), "Hello")
    }

    func testSpacePlusChar() {
        // 0xC0-0xFF: space + (byte XOR 0x80)
        // 0xC0 XOR 0x80 = 0x40 = '@'
        // So 0xC0 → space + '@'
        let input = Data([0xC0])
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(output, Data([0x20, 0x40])) // space + '@'
    }

    func testMultipleSpacePlusChar() {
        // 0xE1 XOR 0x80 = 0x61 = 'a'
        // 0xF4 XOR 0x80 = 0x74 = 't'
        let input = Data([0xE1, 0xF4])
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(String(data: output, encoding: .ascii), " a t")
    }

    func testCopyNBytesLiterally() {
        // 0x03 means: copy next 3 bytes literally
        let input = Data([0x03, 0x01, 0x02, 0x03])
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(output, Data([0x01, 0x02, 0x03]))
    }

    func testNullByte() {
        // 0x00 is literal NUL
        let input = Data([0x41, 0x00, 0x42]) // 'A' NUL 'B'
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(output, Data([0x41, 0x00, 0x42]))
    }

    func testDistanceLengthPair() {
        // Build a simple case: "ABCABC"
        // First "ABC" literal, then back-reference distance=3, length=3
        // distance=3, length=3 → length_bits = 3-3 = 0, distance in bits [14:3]
        // pair = (distance << 3) | length_bits = (3 << 3) | 0 = 24 = 0x0018
        // First byte: 0x80 | (0x0018 >> 8) = 0x80 | 0x00 = 0x80
        // Second byte: 0x18
        let input = Data([0x41, 0x42, 0x43, 0x80, 0x18])
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(String(data: output, encoding: .ascii), "ABCABC")
    }

    func testEmptyInput() {
        let input = Data()
        let output = PalmDOCDecompressor.decompress(input)
        XCTAssertEqual(output, Data())
    }
}
