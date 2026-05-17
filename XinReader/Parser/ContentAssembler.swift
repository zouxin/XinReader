import Foundation

/// Assembles the full HTML content from MOBI text records.
/// Text records are stored sequentially after Record 0, and each may be compressed.
struct ContentAssembler {

    /// Assemble all text records into a single HTML string.
    ///
    /// - Parameters:
    ///   - records: All PDB records (raw bytes)
    ///   - palmDOC: PalmDOC header (compression type, text length, record count)
    ///   - mobi: MOBI header (encoding, content record range, extra data flags)
    /// - Returns: The full HTML content as a String
    static func assemble(
        records: [Data],
        palmDOC: PalmDOCHeader,
        mobi: MOBIHeader
    ) throws -> String {
        // Determine text record range
        let firstText = Int(mobi.firstContentRecord > 0 ? mobi.firstContentRecord : 1)
        let textRecordCount = Int(palmDOC.textRecordCount)
        let lastText = firstText + textRecordCount - 1

        guard lastText < records.count else {
            throw MOBIError.invalidRecordRange(first: firstText, last: lastText, total: records.count)
        }

        var htmlData = Data()
        htmlData.reserveCapacity(Int(palmDOC.textLength))

        for i in firstText...lastText {
            var recordData = records[i]

            // Strip trailing bytes if extra data flags are set
            recordData = stripTrailingBytes(recordData, extraDataFlags: mobi.extraDataFlags)

            let decompressed: Data
            switch palmDOC.compression {
            case .none:
                decompressed = recordData
            case .palmDOC:
                decompressed = PalmDOCDecompressor.decompress(recordData)
            case .huffCDIC:
                throw MOBIError.huffCDICNotSupported
            }

            htmlData.append(decompressed)
        }

        // Truncate to declared text length (removes any padding)
        if htmlData.count > Int(palmDOC.textLength) {
            htmlData = htmlData.prefix(Int(palmDOC.textLength))
        }

        guard let html = String(data: htmlData, encoding: mobi.textEncoding) else {
            // Fallback: try latin1 which never fails
            if let fallback = String(data: htmlData, encoding: .isoLatin1) {
                return fallback
            }
            throw MOBIError.textDecodingFailed
        }

        return html
    }

    // MARK: - Private Helpers

    /// Strip trailing bytes from a text record based on extra data flags.
    ///
    /// MOBI files with version >= 5 may have trailing bytes at the end of each text record.
    /// The extra data flags in the MOBI header indicate which types of trailing data are present.
    /// The last byte of each record (before any trailing entries) encodes the size of trailing data
    /// using a variable-length encoding.
    private static func stripTrailingBytes(_ record: Data, extraDataFlags: UInt32) -> Data {
        guard !record.isEmpty else { return record }

        var data = record
        var flags = extraDataFlags

        // Process each trailing entry (bit 0 is "multibyte overlap" which uses different encoding)
        // Bits 1+ each indicate a trailing entry whose size is encoded in the last bytes

        // First handle the extra trailing entries (bits 1+)
        var bit: UInt32 = 1
        while bit < 16 {
            if flags & (1 << bit) != 0 {
                // The last 1-4 bytes encode the size using a variable-length backward encoding
                let size = getTrailingEntrySize(data)
                if size > 0 && size <= data.count {
                    data = data.prefix(data.count - size)
                }
            }
            bit += 1
            flags >>= 1
        }

        // Handle multibyte overlap (bit 0)
        if extraDataFlags & 1 != 0 && !data.isEmpty {
            // Last byte's low bits tell how many extra trailing bytes
            let trailingCount = Int(data[data.count - 1]) & 0x03
            if trailingCount > 0 && trailingCount < data.count {
                data = data.prefix(data.count - trailingCount)
            }
        }

        return data
    }

    /// Decode the variable-length size of a trailing entry.
    /// The size is encoded in the last bytes using a backward variable-length integer.
    private static func getTrailingEntrySize(_ data: Data) -> Int {
        guard !data.isEmpty else { return 0 }

        var size = 0
        var shift = 0

        // Read backwards from the end
        for i in stride(from: data.count - 1, through: max(0, data.count - 4), by: -1) {
            let byte = data[i]
            size |= Int(byte & 0x7F) << shift

            if byte & 0x80 != 0 {
                // High bit set means this is the last byte of the size encoding
                return size
            }
            shift += 7
        }

        return size
    }
}
