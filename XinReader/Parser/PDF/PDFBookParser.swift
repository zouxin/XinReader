import Foundation
import PDFKit
import AppKit

/// Parses PDF files using Apple's PDFKit framework.
enum PDFBookParser {

    /// Parse a PDF file and return a format-agnostic ParsedBook.
    static func parse(fileURL: URL) throws -> ParsedBook {
        guard let document = PDFDocument(url: fileURL) else {
            throw BookParserError.fileNotReadable(fileURL)
        }

        // Extract metadata
        let attrs = document.documentAttributes ?? [:]
        let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? fileURL.deletingPathExtension().lastPathComponent
        let author = (attrs[PDFDocumentAttribute.authorAttribute] as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Unknown"

        // Extract TOC from PDF outline
        let chapters = extractOutline(document.outlineRoot, document: document, depth: 0)

        // Render first page as cover image
        let coverImage = renderCoverImage(document: document)

        return ParsedBook(
            title: title,
            author: author,
            publisher: nil,
            chapters: chapters,
            content: .pdf(PDFBookContent(document: document)),
            coverImage: coverImage
        )
    }

    // MARK: - Outline Extraction

    /// Recursively walk the PDFOutline tree and convert to [Chapter].
    private static func extractOutline(
        _ outline: PDFOutline?,
        document: PDFDocument,
        depth: Int
    ) -> [Chapter] {
        guard let outline = outline else { return [] }

        var chapters: [Chapter] = []

        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }

            let title = child.label ?? "Section \(i + 1)"

            // Get the page index for this outline item
            var pageIndex: Int? = nil
            if let destination = child.destination,
               let page = destination.page {
                pageIndex = document.index(for: page)
            }

            // Recursively process children
            let subChapters = extractOutline(child, document: document, depth: depth + 1)

            chapters.append(Chapter(
                title: title,
                htmlAnchor: "pdf_page_\(pageIndex ?? 0)",
                sourceOffset: nil,
                children: subChapters,
                depth: depth,
                pageIndex: pageIndex
            ))
        }

        return chapters
    }

    // MARK: - Cover Image

    /// Render the first page of the PDF as a JPEG thumbnail for the library.
    private static func renderCoverImage(document: PDFDocument) -> Data? {
        guard let page = document.page(at: 0) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let maxDim = max(bounds.width, bounds.height)
        guard maxDim > 0 else { return nil }

        let scale: CGFloat = 300.0 / maxDim
        let size = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
