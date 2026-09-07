import Foundation

enum SnappyError: Error {
    case truncatedInput
    case invalidCopyOffset
}

/// Decodes the raw Snappy block format (a leading varint uncompressed-length
/// followed by a literal/copy tag stream). This is Google's published,
/// permissively-licensed block format spec — not tied to any particular
/// implementation.
enum SnappyDecoder {
    static func decompress(_ input: [UInt8]) throws -> [UInt8] {
        var pos = 0
        let uncompressedLength = try readVarint(input, &pos)

        var output = [UInt8]()
        output.reserveCapacity(uncompressedLength)

        while pos < input.count {
            let tag = input[pos]
            pos += 1
            let tagType = tag & 0x3

            if tagType == 0 {
                // Literal.
                var length = Int(tag >> 2)
                if length < 60 {
                    length += 1
                } else {
                    let extraBytes = length - 59
                    guard pos + extraBytes <= input.count else { throw SnappyError.truncatedInput }
                    var literalLength = 0
                    for i in 0..<extraBytes {
                        literalLength |= Int(input[pos + i]) << (8 * i)
                    }
                    pos += extraBytes
                    length = literalLength + 1
                }
                guard pos + length <= input.count else { throw SnappyError.truncatedInput }
                output.append(contentsOf: input[pos..<(pos + length)])
                pos += length
            } else {
                let length: Int
                let offset: Int
                switch tagType {
                case 1:
                    guard pos + 1 <= input.count else { throw SnappyError.truncatedInput }
                    length = Int((tag >> 2) & 0x7) + 4
                    offset = (Int(tag >> 5) << 8) | Int(input[pos])
                    pos += 1
                case 2:
                    guard pos + 2 <= input.count else { throw SnappyError.truncatedInput }
                    length = Int(tag >> 2) + 1
                    offset = Int(input[pos]) | (Int(input[pos + 1]) << 8)
                    pos += 2
                default:
                    guard pos + 4 <= input.count else { throw SnappyError.truncatedInput }
                    length = Int(tag >> 2) + 1
                    offset = Int(input[pos])
                        | (Int(input[pos + 1]) << 8)
                        | (Int(input[pos + 2]) << 16)
                        | (Int(input[pos + 3]) << 24)
                    pos += 4
                }

                guard offset > 0, offset <= output.count else { throw SnappyError.invalidCopyOffset }
                var copyFrom = output.count - offset
                for _ in 0..<length {
                    output.append(output[copyFrom])
                    copyFrom += 1
                }
            }
        }

        return output
    }

    private static func readVarint(_ input: [UInt8], _ pos: inout Int) throws -> Int {
        var result = 0
        var shift = 0
        while true {
            guard pos < input.count else { throw SnappyError.truncatedInput }
            let byte = input[pos]
            pos += 1
            result |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return result
    }
}
