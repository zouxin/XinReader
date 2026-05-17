import Foundation

/// EXTH (Extended Header) parser.
/// Located immediately after MOBI header in Record 0 (if EXTH flag is set).
///
/// Structure:
/// - Offset 0, 4 bytes: "EXTH" identifier
/// - Offset 4, 4 bytes: Header length
/// - Offset 8, 4 bytes: Record count (N)
/// - Offset 12, N records: type(4) + length(4) + data(length-8)
///
/// Common EXTH record types:
/// - 100: Author
/// - 101: Publisher
/// - 103: Description
/// - 106: Publication date
/// - 109: Rights
/// - 201: Cover image offset (index relative to first image record)
/// - 202: Thumbnail image offset
/// - 503: Updated title (preferred over PDB name)
struct EXTHHeader {
    let records: [EXTHRecord]

    struct EXTHRecord {
        let type: UInt32
        let data: Data
    }

    // MARK: - Known record types

    static let authorType: UInt32 = 100
    static let publisherType: UInt32 = 101
    static let descriptionType: UInt32 = 103
    static let publicationDateType: UInt32 = 106
    static let coverOffsetType: UInt32 = 201
    static let thumbnailOffsetType: UInt32 = 202
    static let updatedTitleType: UInt32 = 503

    // MARK: - Parsing

    static func parse(from reader: BinaryReader, encoding: String.Encoding) throws -> EXTHHeader {
        // Identifier "EXTH"
        let identifier = try reader.readString(4, encoding: .ascii)
        guard identifier == "EXTH" else {
            throw MOBIError.invalidEXTHIdentifier(identifier)
        }

        // Header length (includes the "EXTH" identifier and this field)
        let _ = try reader.readUInt32() // headerLength - not needed for parsing

        // Record count
        let recordCount = try reader.readUInt32()

        var records: [EXTHRecord] = []
        records.reserveCapacity(Int(recordCount))

        for _ in 0..<recordCount {
            let type = try reader.readUInt32()
            let length = try reader.readUInt32()

            // Data length = total length - 8 (type + length fields)
            let dataLength = Int(length) - 8
            guard dataLength >= 0 else {
                throw MOBIError.invalidEXTHRecordLength
            }

            let data: Data
            if dataLength > 0 {
                data = try reader.readBytes(dataLength)
            } else {
                data = Data()
            }

            records.append(EXTHRecord(type: type, data: data))
        }

        return EXTHHeader(records: records)
    }

    // MARK: - Convenience Accessors

    /// Get string value for a given EXTH record type
    func string(for type: UInt32, encoding: String.Encoding) -> String? {
        guard let record = records.first(where: { $0.type == type }) else {
            return nil
        }
        return String(data: record.data, encoding: encoding)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get UInt32 value for a given EXTH record type
    func uint32(for type: UInt32) -> UInt32? {
        guard let record = records.first(where: { $0.type == type }),
              record.data.count >= 4 else {
            return nil
        }
        return UInt32(record.data[0]) << 24
            | UInt32(record.data[1]) << 16
            | UInt32(record.data[2]) << 8
            | UInt32(record.data[3])
    }

    /// Get the book title (prefers EXTH 503 over PDB name)
    func title(encoding: String.Encoding) -> String? {
        return string(for: EXTHHeader.updatedTitleType, encoding: encoding)
    }

    /// Get the author name
    func author(encoding: String.Encoding) -> String? {
        return string(for: EXTHHeader.authorType, encoding: encoding)
    }

    /// Get the cover image offset relative to first image record
    var coverOffset: UInt32? {
        return uint32(for: EXTHHeader.coverOffsetType)
    }
}
