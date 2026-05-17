import Foundation

/// Supported book formats.
enum BookFormat: String, Codable {
    case mobi
    case epub
    case pdf

    init?(fromExtension ext: String) {
        switch ext.lowercased() {
        case "mobi", "prc": self = .mobi
        case "epub": self = .epub
        case "pdf": self = .pdf
        default: return nil
        }
    }
}

/// Errors for the top-level parser dispatch.
enum BookParserError: Error, LocalizedError {
    case unsupportedFormat(String)
    case fileNotReadable(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported file format: .\(ext)"
        case .fileNotReadable(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        }
    }
}

/// Routes file URLs to the appropriate format-specific parser.
enum BookParser {

    /// Parse any supported book file. Detects format by extension.
    static func parse(fileURL: URL) throws -> ParsedBook {
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "mobi", "prc":
            return try parseMOBI(fileURL: fileURL)
        case "epub":
            return try EPUBParser.parse(fileURL: fileURL)
        case "pdf":
            return try PDFBookParser.parse(fileURL: fileURL)
        default:
            throw BookParserError.unsupportedFormat(ext)
        }
    }

    /// Wrap existing MOBIParser output into the shared ParsedBook type.
    private static func parseMOBI(fileURL: URL) throws -> ParsedBook {
        let mobi = try MOBIParser.parse(fileURL: fileURL)
        return ParsedBook(
            title: mobi.title,
            author: mobi.author,
            publisher: mobi.publisher,
            chapters: mobi.chapters,
            content: .html(HTMLBookContent(
                htmlString: mobi.htmlContent,
                images: mobi.images,
                textEncoding: mobi.textEncoding
            )),
            coverImage: mobi.coverImage
        )
    }
}
