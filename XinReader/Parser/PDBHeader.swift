import Foundation

/// PDB (Palm Database) header parser.
/// The PDB header is the outermost container for MOBI files.
///
/// Structure (78 bytes + record info table):
/// - Offset 0, 32 bytes: Database name (null-padded)
/// - Offset 32, 2 bytes: Attributes
/// - Offset 34, 2 bytes: Version
/// - Offset 36-59: Various timestamps and IDs
/// - Offset 60, 4 bytes: Type (should be "BOOK")
/// - Offset 64, 4 bytes: Creator (should be "MOBI")
/// - Offset 68-75: Unique ID seed, next record list
/// - Offset 76, 2 bytes: Record count (N)
/// - Offset 78, N*8 bytes: Record info entries
struct PDBHeader {
    let name: String
    let attributes: UInt16
    let version: UInt16
    let type: String
    let creator: String
    let recordCount: UInt16
    let recordInfos: [RecordInfo]

    struct RecordInfo {
        let offset: UInt32
        let attributes: UInt8
        let uniqueID: UInt32 // 3 bytes, packed into UInt32
    }

    /// Parse PDB header from the beginning of a binary reader
    static func parse(from reader: BinaryReader) throws -> PDBHeader {
        // Database name: 32 bytes, null-padded
        let name = try reader.readString(32, encoding: .ascii)

        // Attributes and version
        let attributes = try reader.readUInt16()
        let version = try reader.readUInt16()

        // Skip timestamps and modification info (24 bytes: creation, mod, backup dates + mod number + app info + sort info)
        reader.skip(24)

        // Type and Creator (4 bytes each)
        let type = try reader.readString(4, encoding: .ascii)
        let creator = try reader.readString(4, encoding: .ascii)

        // Skip unique ID seed and next record list (8 bytes)
        reader.skip(8)

        // Record count
        let recordCount = try reader.readUInt16()

        // Record info table: N entries, each 8 bytes
        var recordInfos: [RecordInfo] = []
        recordInfos.reserveCapacity(Int(recordCount))

        for _ in 0..<recordCount {
            let offset = try reader.readUInt32()
            let attrByte = try reader.readUInt8()
            // UniqueID is 3 bytes (big-endian)
            let id1 = try reader.readUInt8()
            let id2 = try reader.readUInt8()
            let id3 = try reader.readUInt8()
            let uniqueID = UInt32(id1) << 16 | UInt32(id2) << 8 | UInt32(id3)

            recordInfos.append(RecordInfo(
                offset: offset,
                attributes: attrByte,
                uniqueID: uniqueID
            ))
        }

        return PDBHeader(
            name: name,
            attributes: attributes,
            version: version,
            type: type,
            creator: creator,
            recordCount: recordCount,
            recordInfos: recordInfos
        )
    }
}
