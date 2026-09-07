import Foundation

enum IWAReaderError: Error, LocalizedError {
    case invalidChunkHeader
    case truncatedArchiveInfo
    case emptyArchive

    var errorDescription: String? {
        switch self {
        case .invalidChunkHeader: return "Malformed .iwa chunk header."
        case .truncatedArchiveInfo: return "Truncated archive segment."
        case .emptyArchive: return "Archive segment has no messages."
        }
    }
}

struct IWAObject {
    let identifier: UInt64
    let typeID: UInt32
    let payload: [UInt8]
}

/// Reads the objects archived in one decoded `Index/*.iwa` file's bytes.
enum IWAReader {
    /// An .iwa file is a sequence of `[0x00][3-byte LE length][snappy-compressed payload]`
    /// chunks; decompressing and concatenating all of them yields a byte stream that is
    /// itself a sequence of length-prefixed `TSP.ArchiveInfo` + message-payload segments.
    static func readObjects(from rawFileData: Data) throws -> [IWAObject] {
        let decompressed = try decompressChunks(Array(rawFileData))
        return try readArchiveSegments(decompressed)
    }

    private static func decompressChunks(_ data: [UInt8]) throws -> [UInt8] {
        var result = [UInt8]()
        var pos = 0

        while pos < data.count {
            guard pos + 4 <= data.count, data[pos] == 0x00 else {
                throw IWAReaderError.invalidChunkHeader
            }
            let length = Int(data[pos + 1]) | (Int(data[pos + 2]) << 8) | (Int(data[pos + 3]) << 16)
            pos += 4
            guard pos + length <= data.count else { throw IWAReaderError.invalidChunkHeader }
            let chunk = Array(data[pos..<(pos + length)])
            pos += length

            if let decompressed = try? SnappyDecoder.decompress(chunk) {
                result.append(contentsOf: decompressed)
            } else {
                // Fall back to treating the chunk as already-uncompressed, matching
                // numbers-parser's behavior for the rare non-Snappy chunk.
                result.append(contentsOf: chunk)
            }
        }

        return result
    }

    private static func readArchiveSegments(_ data: [UInt8]) throws -> [IWAObject] {
        var objects: [IWAObject] = []
        var pos = 0

        while pos < data.count {
            let archiveInfoLength = try readVarint(data, &pos)
            guard pos + archiveInfoLength <= data.count else { throw IWAReaderError.truncatedArchiveInfo }
            let archiveInfoBytes = Array(data[pos..<(pos + archiveInfoLength)])
            pos += archiveInfoLength

            let archiveInfo = try TSP_ArchiveInfo(serializedBytes: archiveInfoBytes)

            var payloadOffset = pos
            for (index, messageInfo) in archiveInfo.messageInfos.enumerated() {
                let length = Int(messageInfo.length)
                guard payloadOffset + length <= data.count else { throw IWAReaderError.truncatedArchiveInfo }
                if index == 0 {
                    let payload = Array(data[payloadOffset..<(payloadOffset + length)])
                    objects.append(IWAObject(
                        identifier: archiveInfo.identifier,
                        typeID: messageInfo.type,
                        payload: payload
                    ))
                }
                payloadOffset += length
            }
            pos = payloadOffset
        }

        return objects
    }

    private static func readVarint(_ data: [UInt8], _ pos: inout Int) throws -> Int {
        var result = 0
        var shift = 0
        while true {
            guard pos < data.count else { throw IWAReaderError.truncatedArchiveInfo }
            let byte = data[pos]
            pos += 1
            result |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return result
    }
}
