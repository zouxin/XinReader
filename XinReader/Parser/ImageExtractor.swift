import Foundation

/// Extracts image records from a MOBI file.
///
/// Images are stored as raw binary data (JPEG, PNG, GIF, BMP) in records
/// starting at the index specified by MOBIHeader.firstImageIndex.
/// MOBI HTML references images using recindex attributes (e.g., recindex="00001").
struct ImageExtractor {

    /// Extract all image records as a dictionary mapping "recindex:NNNNN" to image Data.
    ///
    /// - Parameters:
    ///   - records: All PDB records
    ///   - firstImageIndex: First image record index from MOBI header
    /// - Returns: Dictionary of image key to image data
    static func extractImages(
        records: [Data],
        firstImageIndex: Int
    ) -> [String: Data] {
        guard firstImageIndex > 0 && firstImageIndex < records.count else {
            return [:]
        }

        var images: [String: Data] = [:]

        for i in firstImageIndex..<records.count {
            let data = records[i]
            guard data.count > 4 else { continue }

            // Only include records that are actual images
            if isImageData(data) {
                // MOBI uses 1-based indexing for recindex references
                let recIndex = i - firstImageIndex + 1
                let key = String(format: "recindex:%05d", recIndex)
                images[key] = data
            } else {
                // Once we hit a non-image record after images started,
                // there might be more images further down (FLIS, FCIS records in between)
                // But typically images are contiguous, so we can continue scanning
                continue
            }
        }

        return images
    }

    /// Extract the cover image if specified in EXTH metadata.
    ///
    /// - Parameters:
    ///   - records: All PDB records
    ///   - firstImageIndex: First image record index from MOBI header
    ///   - coverOffset: Cover image offset from EXTH (relative to first image record)
    /// - Returns: Cover image data, or nil if not found
    static func extractCoverImage(
        records: [Data],
        firstImageIndex: Int,
        coverOffset: UInt32?
    ) -> Data? {
        guard let offset = coverOffset else { return nil }

        let coverRecordIndex = firstImageIndex + Int(offset)
        guard coverRecordIndex >= 0 && coverRecordIndex < records.count else {
            return nil
        }

        let data = records[coverRecordIndex]
        return isImageData(data) ? data : nil
    }

    // MARK: - Image Detection

    /// Check if data starts with a known image magic number.
    static func isImageData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }

        let bytes = [UInt8](data.prefix(8))

        // JPEG: FF D8 FF
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return true
        }

        // PNG: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return true
        }

        // GIF: 47 49 46 38 ("GIF8")
        if bytes.count >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return true
        }

        // BMP: 42 4D ("BM")
        if bytes.count >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D {
            return true
        }

        return false
    }

    /// Detect MIME type from image data.
    static func mimeType(for data: Data) -> String {
        guard data.count >= 4 else { return "application/octet-stream" }

        let bytes = [UInt8](data.prefix(4))

        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "image/jpeg"
        } else if bytes[0] == 0x89 && bytes[1] == 0x50 {
            return "image/png"
        } else if bytes[0] == 0x47 && bytes[1] == 0x49 {
            return "image/gif"
        } else if bytes[0] == 0x42 && bytes[1] == 0x4D {
            return "image/bmp"
        }

        return "application/octet-stream"
    }
}
