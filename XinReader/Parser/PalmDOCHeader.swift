import Foundation

/// PalmDOC header parser (first 16 bytes of Record 0).
///
/// Structure:
/// - Offset 0, 2 bytes: Compression type (1=none, 2=PalmDOC LZ77, 17480=HUFF/CDIC)
/// - Offset 2, 2 bytes: Unused (always 0)
/// - Offset 4, 4 bytes: Uncompressed text length
/// - Offset 8, 2 bytes: Text record count
/// - Offset 10, 2 bytes: Max record size (typically 4096)
/// - Offset 12, 2 bytes: Encryption type (0=none, 1=old Mobipocket, 2=Mobipocket DRM)
/// - Offset 14, 2 bytes: Unused
struct PalmDOCHeader {
    let compression: CompressionType
    let textLength: UInt32
    let textRecordCount: UInt16
    let maxRecordSize: UInt16
    let encryptionType: EncryptionType

    enum CompressionType: UInt16 {
        case none = 1
        case palmDOC = 2
        case huffCDIC = 17480

        var description: String {
            switch self {
            case .none: return "No compression"
            case .palmDOC: return "PalmDOC LZ77"
            case .huffCDIC: return "HUFF/CDIC"
            }
        }
    }

    enum EncryptionType: UInt16 {
        case none = 0
        case oldMobipocket = 1
        case mobipocketDRM = 2

        var isEncrypted: Bool { self != .none }
    }

    /// Parse PalmDOC header from the beginning of Record 0
    static func parse(from reader: BinaryReader) throws -> PalmDOCHeader {
        let compressionRaw = try reader.readUInt16()
        guard let compression = CompressionType(rawValue: compressionRaw) else {
            throw MOBIError.unsupportedCompression(compressionRaw)
        }

        // Skip unused 2 bytes
        reader.skip(2)

        let textLength = try reader.readUInt32()
        let textRecordCount = try reader.readUInt16()
        let maxRecordSize = try reader.readUInt16()

        let encryptionRaw = try reader.readUInt16()
        let encryptionType = EncryptionType(rawValue: encryptionRaw) ?? .none

        // Skip unused 2 bytes
        reader.skip(2)

        return PalmDOCHeader(
            compression: compression,
            textLength: textLength,
            textRecordCount: textRecordCount,
            maxRecordSize: maxRecordSize,
            encryptionType: encryptionType
        )
    }
}
