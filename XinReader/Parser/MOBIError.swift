import Foundation

/// Errors that can occur during MOBI file parsing.
enum MOBIError: Error, LocalizedError {
    case fileNotFound(URL)
    case invalidPDBHeader
    case invalidMOBIIdentifier(String)
    case invalidEXTHIdentifier(String)
    case invalidEXTHRecordLength
    case unsupportedCompression(UInt16)
    case huffCDICNotSupported
    case encryptedFile
    case invalidRecordRange(first: Int, last: Int, total: Int)
    case textDecodingFailed
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .invalidPDBHeader:
            return "Invalid PDB header format"
        case .invalidMOBIIdentifier(let id):
            return "Invalid MOBI identifier: '\(id)' (expected 'MOBI')"
        case .invalidEXTHIdentifier(let id):
            return "Invalid EXTH identifier: '\(id)' (expected 'EXTH')"
        case .invalidEXTHRecordLength:
            return "Invalid EXTH record length"
        case .unsupportedCompression(let type):
            return "Unsupported compression type: \(type)"
        case .huffCDICNotSupported:
            return "HUFF/CDIC compression is not yet supported. Most MOBI files use PalmDOC compression."
        case .encryptedFile:
            return "This file is DRM-protected and cannot be opened"
        case .invalidRecordRange(let first, let last, let total):
            return "Invalid record range: records \(first)-\(last) out of \(total) total"
        case .textDecodingFailed:
            return "Failed to decode text content"
        case .emptyFile:
            return "The file appears to be empty"
        }
    }
}
