import Foundation

/// Cursor-based binary data reader for parsing MOBI file structures.
/// All multi-byte integers in MOBI/PDB are big-endian.
final class BinaryReader {
    private let data: Data
    private(set) var cursor: Int = 0

    var remaining: Int { data.count - cursor }
    var isAtEnd: Bool { cursor >= data.count }
    var count: Int { data.count }

    init(data: Data) {
        self.data = data
    }

    // MARK: - Read Primitives

    func readUInt8() throws -> UInt8 {
        guard cursor + 1 <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        let value = data[data.startIndex + cursor]
        cursor += 1
        return value
    }

    func readUInt16() throws -> UInt16 {
        guard cursor + 2 <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        let startIdx = data.startIndex + cursor
        let value = UInt16(data[startIdx]) << 8 | UInt16(data[startIdx + 1])
        cursor += 2
        return value
    }

    func readUInt32() throws -> UInt32 {
        guard cursor + 4 <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        let startIdx = data.startIndex + cursor
        let value = UInt32(data[startIdx]) << 24
            | UInt32(data[startIdx + 1]) << 16
            | UInt32(data[startIdx + 2]) << 8
            | UInt32(data[startIdx + 3])
        cursor += 4
        return value
    }

    func readBytes(_ count: Int) throws -> Data {
        guard cursor + count <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        let startIdx = data.startIndex + cursor
        let result = data[startIdx..<(startIdx + count)]
        cursor += count
        return Data(result)
    }

    func readString(_ count: Int, encoding: String.Encoding = .utf8) throws -> String {
        let bytes = try readBytes(count)
        // Remove null padding
        let trimmed = bytes.prefix(while: { $0 != 0 })
        guard let str = String(data: Data(trimmed), encoding: encoding) else {
            throw BinaryReaderError.stringDecodingFailed
        }
        return str
    }

    // MARK: - Navigation

    func seek(to offset: Int) {
        cursor = min(offset, data.count)
    }

    func skip(_ count: Int) {
        cursor = min(cursor + count, data.count)
    }

    /// Peek at a byte without advancing cursor
    func peekUInt8() throws -> UInt8 {
        guard cursor + 1 <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        return data[data.startIndex + cursor]
    }

    /// Read a slice of data without moving cursor
    func slice(offset: Int, count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw BinaryReaderError.unexpectedEndOfData
        }
        let startIdx = data.startIndex + offset
        return Data(data[startIdx..<(startIdx + count)])
    }
}

// MARK: - Errors

enum BinaryReaderError: Error, LocalizedError {
    case unexpectedEndOfData
    case stringDecodingFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedEndOfData:
            return "Unexpected end of data while reading binary"
        case .stringDecodingFailed:
            return "Failed to decode string from binary data"
        }
    }
}
