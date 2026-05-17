import Foundation

/// Top-level MOBI file parser.
/// Orchestrates all sub-parsers to produce a complete ParsedBook from a .mobi file.
final class MOBIParser {

    /// The complete result of parsing a MOBI file.
    struct ParsedBook {
        let title: String
        let author: String
        let publisher: String?
        let chapters: [Chapter]
        let htmlContent: String
        let images: [String: Data]
        let coverImage: Data?
        let textEncoding: String.Encoding
    }

    /// Parse a MOBI file at the given URL.
    ///
    /// - Parameter fileURL: Path to the .mobi file
    /// - Returns: A ParsedBook containing all extracted content
    /// - Throws: MOBIError for various parsing failures
    static func parse(fileURL: URL) throws -> ParsedBook {
        // Read entire file into memory
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MOBIError.fileNotFound(fileURL)
        }

        guard !data.isEmpty else {
            throw MOBIError.emptyFile
        }

        let reader = BinaryReader(data: data)

        // 1. Parse PDB Header (record offsets)
        let pdb = try PDBHeader.parse(from: reader)

        // 2. Extract all records using offset table
        let records = RecordExtractor.extract(from: data, pdb: pdb)
        guard !records.isEmpty else {
            throw MOBIError.invalidPDBHeader
        }

        // 3. Parse Record 0 headers
        let record0Reader = BinaryReader(data: records[0])

        // 3a. PalmDOC header (first 16 bytes of Record 0)
        let palmDOC = try PalmDOCHeader.parse(from: record0Reader)

        // Check for encryption
        if palmDOC.encryptionType.isEncrypted {
            throw MOBIError.encryptedFile
        }

        // 3b. MOBI header (starts at byte 16)
        let mobi = try MOBIHeader.parse(from: record0Reader)

        // 3c. EXTH header (if present, immediately after MOBI header)
        var exth: EXTHHeader? = nil
        if mobi.hasEXTH {
            exth = try? EXTHHeader.parse(from: record0Reader, encoding: mobi.textEncoding)
        }

        // 4. Extract full name from Record 0
        let fullName = extractFullName(from: records[0], mobi: mobi)

        // 5. Determine title and author
        let title = exth?.title(encoding: mobi.textEncoding) ?? fullName ?? pdb.name
        let author = exth?.author(encoding: mobi.textEncoding) ?? "Unknown"
        let publisher = exth?.string(for: EXTHHeader.publisherType, encoding: mobi.textEncoding)

        // 6. Assemble HTML text from text records
        let html = try ContentAssembler.assemble(
            records: records,
            palmDOC: palmDOC,
            mobi: mobi
        )

        // 7. Extract images
        let images = ImageExtractor.extractImages(
            records: records,
            firstImageIndex: Int(mobi.firstImageIndex)
        )

        // 8. Extract cover image
        let coverImage = ImageExtractor.extractCoverImage(
            records: records,
            firstImageIndex: Int(mobi.firstImageIndex),
            coverOffset: exth?.coverOffset
        )

        // 9. Extract table of contents
        let chapters = TOCExtractor.extractFromHTML(html)

        return ParsedBook(
            title: title,
            author: author,
            publisher: publisher,
            chapters: chapters,
            htmlContent: html,
            images: images,
            coverImage: coverImage,
            textEncoding: mobi.textEncoding
        )
    }

    // MARK: - Private Helpers

    /// Extract the full book name from Record 0 using offsets from MOBI header.
    private static func extractFullName(from record0: Data, mobi: MOBIHeader) -> String? {
        let offset = Int(mobi.fullNameOffset)
        let length = Int(mobi.fullNameLength)

        guard offset >= 0 && length > 0 && offset + length <= record0.count else {
            return nil
        }

        let startIdx = record0.startIndex + offset
        let endIdx = startIdx + length
        let nameData = record0[startIdx..<endIdx]

        // Remove null bytes
        let trimmed = nameData.prefix(while: { $0 != 0 })
        return String(data: Data(trimmed), encoding: mobi.textEncoding)
    }
}
