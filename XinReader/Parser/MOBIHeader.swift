import Foundation

/// MOBI header parser.
/// Starts immediately after PalmDOC header (byte 16 of Record 0).
///
/// Variable-length header. Key fields:
/// - Offset 0, 4 bytes: "MOBI" identifier
/// - Offset 4, 4 bytes: Header length
/// - Offset 8, 2 bytes: MOBI type
/// - Offset 10, 2 bytes: Text encoding (1252=CP1252, 65001=UTF-8)
/// - Offset 80, 4 bytes: Full name offset (from start of Record 0)
/// - Offset 84, 4 bytes: Full name length
/// - Offset 92, 4 bytes: First image record index
/// - Offset 108, 4 bytes: EXTH flags (bit 6 = EXTH present)
struct MOBIHeader {
    let headerLength: UInt32
    let mobiType: UInt16
    let textEncoding: String.Encoding
    let uniqueID: UInt32
    let fileVersion: UInt32
    let fullNameOffset: UInt32
    let fullNameLength: UInt32
    let firstImageIndex: UInt32
    let hasEXTH: Bool
    let firstContentRecord: UInt16
    let lastContentRecord: UInt16
    let locale: UInt32
    let minVersion: UInt32
    let extraDataFlags: UInt32

    /// Parse MOBI header from current position in reader (should be at byte 16 of Record 0)
    static func parse(from reader: BinaryReader) throws -> MOBIHeader {
        let startPosition = reader.cursor

        // Identifier "MOBI"
        let identifier = try reader.readString(4, encoding: .ascii)
        guard identifier == "MOBI" else {
            throw MOBIError.invalidMOBIIdentifier(identifier)
        }

        // Header length
        let headerLength = try reader.readUInt32()

        // MOBI type
        let mobiType = try reader.readUInt16()

        // Text encoding
        let encodingRaw = try reader.readUInt16()
        let textEncoding: String.Encoding
        switch encodingRaw {
        case 65001:
            textEncoding = .utf8
        case 1252:
            textEncoding = .windowsCP1252
        default:
            textEncoding = .utf8 // Default fallback
        }

        // Unique ID
        let uniqueID = try reader.readUInt32()

        // File version
        let fileVersion = try reader.readUInt32()

        // Skip to offset 80 from MOBI header start (current is at offset 20 from start)
        // We need to skip: orthographic index, inflection index, index names, index keys,
        // extra index 0-5, first non-book index, full name offset...
        // Offset 24 to 80 = 56 bytes to skip from current position (we're at offset 20 relative to MOBI start)
        reader.skip(60) // skip from offset 20 to offset 80

        // Full name offset (from start of Record 0, not MOBI header)
        let fullNameOffset = try reader.readUInt32()

        // Full name length
        let fullNameLength = try reader.readUInt32()

        // Language/locale (offset 88)
        let locale = try reader.readUInt32()

        // First image record index (offset 92, relative to MOBI header start)
        let firstImageIndex = try reader.readUInt32()

        // Skip huffman record offset, huffman record count (8 bytes) -> offset 100
        reader.skip(8)

        // Skip to EXTH flags at offset 108 from MOBI header start
        // Currently at offset 100, need to skip 8 more bytes
        reader.skip(8)

        // EXTH flags (offset 108 from MOBI header start)
        let exthFlags = try reader.readUInt32()
        let hasEXTH = (exthFlags & 0x40) != 0

        // Try to read first/last content record and extra data flags
        // These are at different offsets depending on MOBI version
        var firstContentRecord: UInt16 = 1
        var lastContentRecord: UInt16 = 0
        let minVersion: UInt32 = 0
        var extraDataFlags: UInt32 = 0

        // Seek to offset 192 from MOBI header start for first/last content record
        let currentOffset = reader.cursor - startPosition
        if headerLength >= 196 && currentOffset < 192 {
            reader.seek(to: startPosition + 192)
            firstContentRecord = try reader.readUInt16()
            lastContentRecord = try reader.readUInt16()
        }

        // Min version at offset 104 area - we already passed it
        // Extra data flags at offset 240 from MOBI header start
        if headerLength >= 244 {
            reader.seek(to: startPosition + 240)
            extraDataFlags = try reader.readUInt32()
        }

        // Seek past the entire MOBI header
        reader.seek(to: startPosition + Int(headerLength))

        return MOBIHeader(
            headerLength: headerLength,
            mobiType: mobiType,
            textEncoding: textEncoding,
            uniqueID: uniqueID,
            fileVersion: fileVersion,
            fullNameOffset: fullNameOffset,
            fullNameLength: fullNameLength,
            firstImageIndex: firstImageIndex,
            hasEXTH: hasEXTH,
            firstContentRecord: firstContentRecord,
            lastContentRecord: lastContentRecord,
            locale: locale,
            minVersion: minVersion,
            extraDataFlags: extraDataFlags
        )
    }
}
