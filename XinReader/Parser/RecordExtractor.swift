import Foundation

/// Extracts raw record data slices from the PDB file using the offset table.
struct RecordExtractor {

    /// Extract all records as individual Data slices.
    /// Each record spans from its offset to the next record's offset (or EOF for the last one).
    static func extract(from fileData: Data, pdb: PDBHeader) -> [Data] {
        var records: [Data] = []
        records.reserveCapacity(Int(pdb.recordCount))

        for i in 0..<Int(pdb.recordCount) {
            let startOffset = Int(pdb.recordInfos[i].offset)
            let endOffset: Int

            if i + 1 < Int(pdb.recordCount) {
                endOffset = Int(pdb.recordInfos[i + 1].offset)
            } else {
                endOffset = fileData.count
            }

            // Safety check
            guard startOffset < fileData.count && endOffset <= fileData.count && startOffset < endOffset else {
                records.append(Data())
                continue
            }

            let startIdx = fileData.startIndex + startOffset
            let endIdx = fileData.startIndex + endOffset
            records.append(Data(fileData[startIdx..<endIdx]))
        }

        return records
    }
}
