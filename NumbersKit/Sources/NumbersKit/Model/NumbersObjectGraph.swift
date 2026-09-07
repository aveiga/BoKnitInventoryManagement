import Foundation
import SwiftProtobuf

enum NumbersDocumentError: Error, LocalizedError {
    case rootNotFound
    case sheetNotFound(String)
    case malformedDocument(String)

    var errorDescription: String? {
        switch self {
        case .rootNotFound: return "Couldn't find the document's root object."
        case .sheetNotFound(let name): return "Couldn't find a sheet named \"\(name)\"."
        case .malformedDocument(let detail): return "Malformed Numbers document: \(detail)."
        }
    }
}

/// Type IDs for the small subset of archived object types NumbersKit understands.
/// See NumbersKit/Sources/NumbersKit/Proto/NOTICE.md for where these came from.
enum NumbersMessageType {
    static let documentArchive: UInt32 = 1
    static let sheetArchive: UInt32 = 2
    static let tableInfoArchive: UInt32 = 6000
    static let tableModelArchive: UInt32 = 6001
    static let tile: UInt32 = 6002
    static let tableDataList: Set<UInt32> = [6005, 6201]
    static let tableDataListSegment: UInt32 = 6011
    static let headerStorageBucket: UInt32 = 6006
}

/// The whole-document object index: identifier -> (type, raw protobuf payload).
/// Objects are decoded into concrete message types lazily, on demand.
final class NumbersObjectGraph {
    private var objectsByIdentifier: [UInt64: IWAObject] = [:]

    init(zip: MinimalZipReader) throws {
        let iwaEntryNames = zip.entryNames.filter {
            $0.hasPrefix("Index/") && $0.hasSuffix(".iwa")
        }
        for name in iwaEntryNames {
            guard let fileData = try? zip.contents(of: name) else { continue }
            guard let objects = try? IWAReader.readObjects(from: fileData) else { continue }
            for object in objects {
                objectsByIdentifier[object.identifier] = object
            }
        }
    }

    func object(for identifier: UInt64) -> IWAObject? {
        objectsByIdentifier[identifier]
    }

    func firstObject(ofType typeID: UInt32) -> IWAObject? {
        objectsByIdentifier.values.first { $0.typeID == typeID }
    }

    func decode<T: SwiftProtobuf.Message>(_ reference: TSP_Reference, as type: T.Type) throws -> T {
        guard let object = objectsByIdentifier[reference.identifier] else {
            throw NumbersDocumentError.malformedDocument("missing object \(reference.identifier)")
        }
        return try T(serializedBytes: object.payload)
    }

    func decodeIfMatching<T: SwiftProtobuf.Message>(
        _ reference: TSP_Reference,
        typeID: UInt32,
        as type: T.Type
    ) -> T? {
        guard let object = objectsByIdentifier[reference.identifier], object.typeID == typeID else {
            return nil
        }
        return try? T(serializedBytes: object.payload)
    }

    func decodeIfMatching<T: SwiftProtobuf.Message>(
        _ reference: TSP_Reference,
        typeIDs: Set<UInt32>,
        as type: T.Type
    ) -> T? {
        guard let object = objectsByIdentifier[reference.identifier], typeIDs.contains(object.typeID) else {
            return nil
        }
        return try? T(serializedBytes: object.payload)
    }
}
