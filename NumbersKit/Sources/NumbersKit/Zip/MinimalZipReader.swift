import Foundation
import Compression

enum ZipReaderError: Error, LocalizedError {
    case notAZipFile
    case zip64Unsupported
    case entryNotFound(String)
    case unsupportedCompressionMethod(UInt16)
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .notAZipFile: return "Not a valid zip archive."
        case .zip64Unsupported: return "This file uses ZIP64, which isn't supported."
        case .entryNotFound(let name): return "Entry \"\(name)\" not found in archive."
        case .unsupportedCompressionMethod(let method): return "Unsupported zip compression method \(method)."
        case .decompressionFailed: return "Failed to decompress zip entry."
        }
    }
}

/// Reads named entries out of a (non-ZIP64) zip archive, without needing to
/// list or decompress every entry up front.
struct MinimalZipReader {
    private struct CentralDirectoryEntry {
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    private let data: Data
    private let entriesByName: [String: CentralDirectoryEntry]

    init(data: Data) throws {
        self.data = data
        self.entriesByName = try Self.readCentralDirectory(data)
    }

    var entryNames: [String] { Array(entriesByName.keys) }

    func contents(of name: String) throws -> Data {
        guard let entry = entriesByName[name] else {
            throw ZipReaderError.entryNotFound(name)
        }

        let localHeaderStart = Int(entry.localHeaderOffset)
        guard localHeaderStart + 30 <= data.count else { throw ZipReaderError.notAZipFile }
        guard readUInt32(at: localHeaderStart) == 0x0403_4b50 else { throw ZipReaderError.notAZipFile }

        let nameLength = Int(readUInt16(at: localHeaderStart + 26))
        let extraLength = Int(readUInt16(at: localHeaderStart + 28))
        let dataStart = localHeaderStart + 30 + nameLength + extraLength
        let compressedSize = Int(entry.compressedSize)
        guard dataStart + compressedSize <= data.count else { throw ZipReaderError.notAZipFile }

        let compressed = data.subdata(in: dataStart..<(dataStart + compressedSize))

        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return try Self.inflate(compressed)
        default:
            throw ZipReaderError.unsupportedCompressionMethod(entry.compressionMethod)
        }
    }

    private static func readCentralDirectory(_ data: Data) throws -> [String: CentralDirectoryEntry] {
        // Locate the End Of Central Directory record by scanning backwards for its signature.
        // The record is fixed-size (22 bytes) plus an optional comment, so it can't be far from the end.
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let searchWindow = min(data.count, 66_000)
        let searchStart = data.count - searchWindow
        var eocdOffset: Int?

        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var i = data.count - 4
            while i >= searchStart {
                if bytes[i] == signature[0], bytes[i + 1] == signature[1],
                   bytes[i + 2] == signature[2], bytes[i + 3] == signature[3] {
                    eocdOffset = i
                    break
                }
                i -= 1
            }
        }

        guard let eocd = eocdOffset else { throw ZipReaderError.notAZipFile }

        let entryCount = Int(readUInt16(data, at: eocd + 10))
        let centralDirectorySize = Int(readUInt32(data, at: eocd + 12))
        let centralDirectoryOffset = Int(readUInt32(data, at: eocd + 16))

        if entryCount == 0xFFFF || centralDirectoryOffset == 0xFFFF_FFFF {
            throw ZipReaderError.zip64Unsupported
        }
        guard centralDirectoryOffset + centralDirectorySize <= data.count else {
            throw ZipReaderError.notAZipFile
        }

        var entries: [String: CentralDirectoryEntry] = [:]
        var cursor = centralDirectoryOffset

        for _ in 0..<entryCount {
            guard readUInt32(data, at: cursor) == 0x0201_4b50 else { throw ZipReaderError.notAZipFile }

            let compressionMethod = readUInt16(data, at: cursor + 10)
            let compressedSize = readUInt32(data, at: cursor + 20)
            let nameLength = Int(readUInt16(data, at: cursor + 28))
            let extraLength = Int(readUInt16(data, at: cursor + 30))
            let commentLength = Int(readUInt16(data, at: cursor + 32))
            let localHeaderOffset = readUInt32(data, at: cursor + 42)

            let nameStart = cursor + 46
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            let name = String(decoding: nameData, as: UTF8.self)

            entries[name] = CentralDirectoryEntry(
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                localHeaderOffset: localHeaderOffset
            )

            cursor = nameStart + nameLength + extraLength + commentLength
        }

        return entries
    }

    private func readUInt16(at offset: Int) -> UInt16 { Self.readUInt16(data, at: offset) }
    private func readUInt32(at offset: Int) -> UInt32 { Self.readUInt32(data, at: offset) }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[data.startIndex + offset]) | (UInt16(data[data.startIndex + offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(data[data.startIndex + offset + i]) << (8 * i)
        }
        return value
    }

    /// Zip's "deflate" method is raw DEFLATE with no zlib/gzip header, which is exactly what
    /// Apple's Compression framework's `.zlib` algorithm decodes.
    private static func inflate(_ compressed: Data) throws -> Data {
        var bufferSize = max(compressed.count * 8, 1 << 16)
        let sourceBuffer = [UInt8](compressed)

        // compression_decode_buffer is one-shot; if the guessed output size was too small, retry larger.
        for _ in 0..<4 {
            var destinationBuffer = [UInt8](repeating: 0, count: bufferSize)
            let decodedCount = destinationBuffer.withUnsafeMutableBytes { destPtr -> Int in
                sourceBuffer.withUnsafeBytes { srcPtr -> Int in
                    compression_decode_buffer(
                        destPtr.bindMemory(to: UInt8.self).baseAddress!, bufferSize,
                        srcPtr.bindMemory(to: UInt8.self).baseAddress!, sourceBuffer.count,
                        nil, COMPRESSION_ZLIB
                    )
                }
            }
            if decodedCount > 0, decodedCount < bufferSize {
                return Data(destinationBuffer[0..<decodedCount])
            }
            bufferSize *= 4
        }

        throw ZipReaderError.decompressionFailed
    }
}
