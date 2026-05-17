import Foundation
import PDFKit

/// Format-agnostic result of parsing any supported book file.
struct ParsedBook {
    let title: String
    let author: String
    let publisher: String?
    let chapters: [Chapter]
    let content: BookContent
    let coverImage: Data?
}

/// The renderable content payload, varying by source format.
enum BookContent {
    /// HTML-based content (MOBI, EPUB) → rendered in WKWebView
    case html(HTMLBookContent)
    /// PDF content → rendered in PDFView
    case pdf(PDFBookContent)
}

struct HTMLBookContent {
    let htmlString: String
    let images: [String: Data]
    let textEncoding: String.Encoding
}

struct PDFBookContent {
    let document: PDFDocument
}
