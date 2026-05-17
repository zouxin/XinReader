import XCTest
@testable import XinReader

final class BinaryReaderTests: XCTestCase {

    func testReadUInt8() throws {
        let data = Data([0x42])
        let reader = BinaryReader(data: data)
        XCTAssertEqual(try reader.readUInt8(), 0x42)
        XCTAssertEqual(reader.remaining, 0)
    }

    func testReadUInt16BigEndian() throws {
        let data = Data([0x01, 0x02])
        let reader = BinaryReader(data: data)
        XCTAssertEqual(try reader.readUInt16(), 0x0102)
    }

    func testReadUInt32BigEndian() throws {
        let data = Data([0x00, 0x01, 0x00, 0x02])
        let reader = BinaryReader(data: data)
        XCTAssertEqual(try reader.readUInt32(), 0x00010002)
    }

    func testReadBytes() throws {
        let data = Data([0x0A, 0x0B, 0x0C, 0x0D])
        let reader = BinaryReader(data: data)
        let bytes = try reader.readBytes(3)
        XCTAssertEqual(bytes, Data([0x0A, 0x0B, 0x0C]))
        XCTAssertEqual(reader.remaining, 1)
    }

    func testReadStringTrimsNull() throws {
        // "Hi" followed by null padding
        let data = Data([0x48, 0x69, 0x00, 0x00, 0x00])
        let reader = BinaryReader(data: data)
        let str = try reader.readString(5, encoding: .ascii)
        XCTAssertEqual(str, "Hi")
    }

    func testSeekAndSkip() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let reader = BinaryReader(data: data)
        reader.seek(to: 3)
        XCTAssertEqual(try reader.readUInt8(), 0x04)
        reader.seek(to: 0)
        reader.skip(2)
        XCTAssertEqual(try reader.readUInt8(), 0x03)
    }

    func testReadPastEndThrows() {
        let data = Data([0x01])
        let reader = BinaryReader(data: data)
        XCTAssertThrowsError(try reader.readUInt16())
    }

    func testSlice() throws {
        let data = Data([0x10, 0x20, 0x30, 0x40, 0x50])
        let reader = BinaryReader(data: data)
        let slice = try reader.slice(offset: 2, count: 2)
        XCTAssertEqual(slice, Data([0x30, 0x40]))
        // Cursor should not have moved
        XCTAssertEqual(reader.remaining, 5)
    }
}
