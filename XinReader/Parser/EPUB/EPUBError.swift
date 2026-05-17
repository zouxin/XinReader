import Foundation

/// Errors that can occur during EPUB parsing.
enum EPUBError: Error, LocalizedError {
    case invalidArchive
    case containerNotFound
    case opfNotFound
    case opfParseFailed(String)
    case spineEmpty
    case contentFileNotFound(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Invalid or corrupted EPUB file"
        case .containerNotFound:
            return "EPUB container.xml not found (META-INF/container.xml)"
        case .opfNotFound:
            return "EPUB package file (OPF) not found"
        case .opfParseFailed(let detail):
            return "Failed to parse EPUB package: \(detail)"
        case .spineEmpty:
            return "EPUB has no readable content (empty spine)"
        case .contentFileNotFound(let path):
            return "Content file missing from EPUB: \(path)"
        case .encodingError:
            return "Failed to decode EPUB text content"
        }
    }
}
