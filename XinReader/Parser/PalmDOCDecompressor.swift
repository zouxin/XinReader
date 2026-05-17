import Foundation

/// PalmDOC LZ77 decompressor.
///
/// The PalmDOC compression scheme processes bytes as follows:
/// - 0x00: Output literal NUL byte
/// - 0x01-0x08: Copy next N bytes literally to output
/// - 0x09-0x7F: Output literal byte (printable ASCII)
/// - 0x80-0xBF: Two-byte distance-length pair (copy from previous output)
/// - 0xC0-0xFF: Output space (0x20) followed by (byte XOR 0x80)
struct PalmDOCDecompressor {

    /// Decompress a single PalmDOC-compressed record
    static func decompress(_ input: Data) -> Data {
        var output = Data()
        output.reserveCapacity(input.count * 2) // Rough estimate

        var i = input.startIndex

        while i < input.endIndex {
            let byte = input[i]
            i += 1

            switch byte {
            case 0x00:
                // Literal NUL byte
                output.append(byte)

            case 0x01...0x08:
                // Copy next N bytes literally
                let count = Int(byte)
                let end = min(i + count, input.endIndex)
                output.append(contentsOf: input[i..<end])
                i = end

            case 0x09...0x7F:
                // Literal byte (mostly printable ASCII)
                output.append(byte)

            case 0x80...0xBF:
                // Distance-length pair: 2 bytes total
                guard i < input.endIndex else { break }
                let nextByte = input[i]
                i += 1

                // Combine into 16-bit value
                let pair = (UInt16(byte) << 8) | UInt16(nextByte)

                // Distance: bits [14:3] (top 2 bits of first byte are the 0x80 marker,
                // so mask them off, then shift right 3)
                let distance = Int((pair >> 3) & 0x7FF)

                // Length: bits [2:0] + 3
                let length = Int(pair & 0x07) + 3

                // Copy 'length' bytes from 'distance' back in output
                // Must copy byte-by-byte because source may overlap with destination
                // (this is how LZ77 encodes run-length patterns)
                guard distance > 0 else { break }
                for _ in 0..<length {
                    let srcIndex = output.count - distance
                    if srcIndex >= 0 && srcIndex < output.count {
                        output.append(output[srcIndex])
                    } else {
                        // Invalid back-reference, output space as fallback
                        output.append(0x20)
                    }
                }

            case 0xC0...0xFF:
                // Space + character encoding
                output.append(0x20)           // Space character
                output.append(byte ^ 0x80)    // XOR to get actual character

            default:
                break
            }
        }

        return output
    }
}
