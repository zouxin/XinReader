import Foundation
import ZIPFoundation

/// Top-level EPUB parser.
/// Orchestrates container parsing, OPF parsing, TOC extraction, and content assembly.
final class EPUBParser {

    /// Parse an EPUB file and return a format-agnostic ParsedBook.
    static func parse(fileURL: URL) throws -> ParsedBook {
        // 1. Open ZIP archive
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw EPUBError.invalidArchive
        }

        // 2. Find OPF path from container.xml
        let opfPath = try ContainerParser.parse(archive: archive)

        // 3. Parse OPF (metadata, manifest, spine)
        let basePath = (opfPath as NSString).deletingLastPathComponent
        let opf = try OPFParser.parse(archive: archive, opfPath: opfPath)

        // 4. Parse TOC
        let chapters = try EPUBTOCParser.parse(
            archive: archive, opf: opf, basePath: basePath
        )

        // 5. Assemble content (concatenated HTML + images)
        let assembled = try EPUBContentAssembler.assemble(
            archive: archive, opf: opf, basePath: basePath
        )

        // 6. Extract cover image
        let coverImage = extractCoverImage(
            archive: archive, opf: opf, basePath: basePath
        )

        return ParsedBook(
            title: opf.metadata.title ?? fileURL.deletingPathExtension().lastPathComponent,
            author: opf.metadata.author ?? "Unknown",
            publisher: opf.metadata.publisher,
            chapters: chapters,
            content: .html(HTMLBookContent(
                htmlString: assembled.html,
                images: assembled.images,
                textEncoding: .utf8
            )),
            coverImage: coverImage
        )
    }

    // MARK: - Cover Image Extraction

    /// Extract the cover image from the EPUB archive.
    private static func extractCoverImage(
        archive: Archive,
        opf: OPFDocument,
        basePath: String
    ) -> Data? {
        // Strategy 1: Look for cover in EXTH-style metadata
        if let coverID = opf.metadata.coverImageID,
           let coverItem = opf.manifest[coverID] {
            let coverPath = basePath.isEmpty ? coverItem.href : basePath + "/" + coverItem.href
            return readEntry(archive: archive, path: coverPath)
        }

        // Strategy 2: Look for manifest item with properties="cover-image"
        if let coverItem = opf.manifest.values.first(where: { $0.properties?.contains("cover-image") == true }) {
            let coverPath = basePath.isEmpty ? coverItem.href : basePath + "/" + coverItem.href
            return readEntry(archive: archive, path: coverPath)
        }

        // Strategy 3: Look for common cover image names
        let coverNames = ["cover.jpg", "cover.jpeg", "cover.png", "Cover.jpg", "Cover.png"]
        for item in opf.manifest.values where item.mediaType.hasPrefix("image/") {
            let filename = (item.href as NSString).lastPathComponent
            if coverNames.contains(filename) {
                let coverPath = basePath.isEmpty ? item.href : basePath + "/" + item.href
                return readEntry(archive: archive, path: coverPath)
            }
        }

        return nil
    }

    /// Read a single entry from the ZIP archive.
    private static func readEntry(archive: Archive, path: String) -> Data? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        _ = try? archive.extract(entry) { chunk in data.append(chunk) }
        return data.isEmpty ? nil : data
    }
}
