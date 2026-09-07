import Foundation

enum NumbersTableDecoderError: Error, LocalizedError {
    case preBncStorageUnsupported
    case unsupportedCellVersion(UInt8)
    case unsupportedCellType(UInt8)

    var errorDescription: String? {
        switch self {
        case .preBncStorageUnsupported:
            return "This table was saved by an older version of Numbers that isn't supported."
        case .unsupportedCellVersion(let version):
            return "Unsupported cell storage version \(version)."
        case .unsupportedCellType(let type):
            return "Unsupported cell type \(type)."
        }
    }
}

/// Apple's reference date (2001-01-01), used by date/duration cell storage.
private let appleEpoch = Date(timeIntervalSince1970: 978_307_200)
private let decimal128Bias = 0x1820

enum NumbersTableDecoder {
    static func rows(
        for tableModel: TST_TableModelArchive,
        graph: NumbersObjectGraph
    ) throws -> [[NumbersCellValue]] {
        let dataStore = tableModel.baseDataStore
        let numberOfRows = Int(tableModel.numberOfRows)
        let numberOfColumns = Int(tableModel.numberOfColumns)

        let stringTable = try decodeStringTable(dataStore.stringTable, graph: graph)
        let rowBucketMap = try decodeRowBucketMap(dataStore.rowHeaders, graph: graph)
        let flatRowBuffers = try flattenStorageBuffers(dataStore.tiles, numberOfColumns: numberOfColumns, graph: graph)

        var grid: [[NumbersCellValue]] = []
        grid.reserveCapacity(numberOfRows)

        for row in 0..<numberOfRows {
            guard let bucketIndex = rowBucketMap[row], bucketIndex < flatRowBuffers.count else {
                grid.append(Array(repeating: .empty, count: numberOfColumns))
                continue
            }
            let rowBuffers = flatRowBuffers[bucketIndex]
            var rowValues: [NumbersCellValue] = []
            rowValues.reserveCapacity(numberOfColumns)
            for col in 0..<numberOfColumns {
                guard col < rowBuffers.count, let buffer = rowBuffers[col] else {
                    rowValues.append(.empty)
                    continue
                }
                rowValues.append(try decodeCell(buffer: buffer, stringTable: stringTable))
            }
            grid.append(rowValues)
        }

        return grid
    }

    // MARK: - String table

    private static func decodeStringTable(
        _ reference: TSP_Reference,
        graph: NumbersObjectGraph
    ) throws -> [UInt32: String] {
        guard let list = graph.decodeIfMatching(
            reference, typeIDs: NumbersMessageType.tableDataList, as: TST_TableDataList.self
        ) else {
            return [:]
        }

        var strings: [UInt32: String] = [:]
        for entry in list.entries where entry.hasString {
            strings[entry.key] = entry.string
        }
        for segmentRef in list.segments {
            guard let segment = graph.decodeIfMatching(
                segmentRef, typeID: NumbersMessageType.tableDataListSegment, as: TST_TableDataListSegment.self
            ) else { continue }
            for entry in segment.entries where entry.hasString {
                strings[entry.key] = entry.string
            }
        }
        return strings
    }

    // MARK: - Row -> storage-bucket mapping

    /// Empty rows have no storage buffer at all; `rowHeaders.buckets` gives, in storage order,
    /// which logical row each sequential populated storage-buffer entry belongs to.
    private static func decodeRowBucketMap(
        _ rowHeaders: TST_HeaderStorage,
        graph: NumbersObjectGraph
    ) throws -> [Int: Int] {
        var map: [Int: Int] = [:]
        var idx = 0
        for bucketRef in rowHeaders.buckets {
            guard let bucket = graph.decodeIfMatching(
                bucketRef, typeID: NumbersMessageType.headerStorageBucket, as: TST_HeaderStorageBucket.self
            ) else { continue }
            for header in bucket.headers {
                map[Int(header.index)] = idx
                idx += 1
            }
        }
        return map
    }

    // MARK: - Tiles -> per-row per-column raw cell buffers, in storage order

    private static func flattenStorageBuffers(
        _ tileStorage: TST_TileStorage,
        numberOfColumns: Int,
        graph: NumbersObjectGraph
    ) throws -> [[Data?]] {
        var rows: [[Data?]] = []
        for tileEntry in tileStorage.tiles {
            guard let tile = graph.decodeIfMatching(
                tileEntry.tile, typeID: NumbersMessageType.tile, as: TST_Tile.self
            ) else { continue }
            guard tile.lastSavedInBnc else { throw NumbersTableDecoderError.preBncStorageUnsupported }

            for rowInfo in tile.rowInfos {
                rows.append(cellBuffers(
                    storageBuffer: rowInfo.cellStorageBuffer,
                    offsetsData: rowInfo.cellOffsets,
                    numberOfColumns: numberOfColumns,
                    hasWideOffsets: rowInfo.hasWideOffsets_p
                ))
            }
        }
        return rows
    }

    private static func cellBuffers(
        storageBuffer: Data,
        offsetsData: Data,
        numberOfColumns: Int,
        hasWideOffsets: Bool
    ) -> [Data?] {
        let rawOffsets = offsetsData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [Int] in
            let count = offsetsData.count / 2
            var values: [Int] = []
            values.reserveCapacity(count)
            for i in 0..<count {
                let low = UInt16(raw[i * 2])
                let high = UInt16(raw[i * 2 + 1])
                let bitPattern = low | (high << 8)
                values.append(Int(Int16(bitPattern: bitPattern)))
            }
            return values
        }
        let offsets = hasWideOffsets ? rawOffsets.map { $0 * 4 } : rawOffsets

        var result: [Data?] = []
        result.reserveCapacity(numberOfColumns)
        for col in 0..<numberOfColumns {
            guard col < offsets.count else { break }
            let start = offsets[col]
            guard start >= 0 else {
                result.append(nil)
                continue
            }
            var end = storageBuffer.count
            if col < offsets.count - 1 {
                for next in offsets[(col + 1)...] where next >= 0 {
                    end = next
                    break
                }
            }
            let base = storageBuffer.startIndex
            result.append(storageBuffer.subdata(in: (base + start)..<(base + end)))
        }
        return result
    }

    // MARK: - Per-cell binary record decoding

    private static func decodeCell(buffer: Data, stringTable: [UInt32: String]) throws -> NumbersCellValue {
        let bytes = [UInt8](buffer)
        guard bytes.count >= 12 else { throw NumbersTableDecoderError.unsupportedCellVersion(0) }

        let version = bytes[0]
        guard version == 5 else { throw NumbersTableDecoderError.unsupportedCellVersion(version) }
        let cellType = bytes[1]

        let flags = readInt32(bytes, at: 8)
        var offset = 12

        var decimal128: Double?
        var double: Double?
        var seconds: Double?
        var stringID: UInt32?

        if flags & 0x1 != 0, offset + 16 <= bytes.count {
            decimal128 = unpackDecimal128(bytes, at: offset)
            offset += 16
        }
        if flags & 0x2 != 0, offset + 8 <= bytes.count {
            double = readDouble(bytes, at: offset)
            offset += 8
        }
        if flags & 0x4 != 0, offset + 8 <= bytes.count {
            seconds = readDouble(bytes, at: offset)
            offset += 8
        }
        if flags & 0x8 != 0, offset + 4 <= bytes.count {
            stringID = UInt32(bitPattern: readInt32(bytes, at: offset))
            offset += 4
        }
        // Remaining flagged fields (rich text/style/formula/format IDs, etc.) aren't needed
        // for reading plain values, so they're intentionally not parsed.

        switch cellType {
        case 0: // genericCellType (empty)
            return .empty
        case 1: // spanCellType (continuation of a merged cell)
            return .empty
        case 2: // numberCellType
            return .number(decimal128 ?? 0)
        case 3: // textCellType
            guard let stringID, let text = stringTable[stringID] else { return .empty }
            return .text(text)
        case 5: // dateCellType
            guard let seconds else { return .empty }
            return .date(appleEpoch.addingTimeInterval(seconds))
        case 6: // boolCellType
            return .bool((double ?? 0) > 0)
        case 7: // durationCellType
            return .number(double ?? 0)
        case 8: // formulaErrorCellType
            return .error
        case 9: // automaticCellType (rich text) — not supported, treat as empty
            return .empty
        case 10: // currency
            return .number(decimal128 ?? 0)
        default:
            throw NumbersTableDecoderError.unsupportedCellType(cellType)
        }
    }

    private static func readInt32(_ bytes: [UInt8], at offset: Int) -> Int32 {
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(bytes[offset + i]) << (8 * i)
        }
        return Int32(bitPattern: value)
    }

    private static func readDouble(_ bytes: [UInt8], at offset: Int) -> Double {
        var value: UInt64 = 0
        for i in 0..<8 {
            value |= UInt64(bytes[offset + i]) << (8 * i)
        }
        return Double(bitPattern: value)
    }

    /// IEEE 754-2008 decimal128, as used by Numbers' number cells.
    private static func unpackDecimal128(_ bytes: [UInt8], at offset: Int) -> Double {
        let b15 = bytes[offset + 15]
        let b14 = bytes[offset + 14]
        let exponent = ((Int(b15 & 0x7F) << 7) | Int(b14 >> 1)) - decimal128Bias
        var mantissa = Double(b14 & 1)
        var i = 13
        while i >= 0 {
            mantissa = mantissa * 256 + Double(bytes[offset + i])
            i -= 1
        }
        if b15 & 0x80 != 0 {
            mantissa = -mantissa
        }
        return mantissa * pow(10, Double(exponent))
    }
}
