import Foundation

public struct NumbersDocument {
    public let sheets: [NumbersSheet]

    public init(fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        try self.init(data: data)
    }

    public init(data: Data) throws {
        let zip = try MinimalZipReader(data: data)
        let graph = try NumbersObjectGraph(zip: zip)

        guard let documentObject = graph.firstObject(ofType: NumbersMessageType.documentArchive) else {
            throw NumbersDocumentError.rootNotFound
        }
        let document = try TN_DocumentArchive(serializedBytes: documentObject.payload)

        self.sheets = try document.sheets.compactMap { sheetRef in
            guard let sheetArchive = graph.decodeIfMatching(
                sheetRef, typeID: NumbersMessageType.sheetArchive, as: TN_SheetArchive.self
            ) else { return nil }

            let tables: [NumbersTable] = try sheetArchive.drawableInfos.compactMap { drawableRef in
                guard let tableInfo = graph.decodeIfMatching(
                    drawableRef, typeID: NumbersMessageType.tableInfoArchive, as: TST_TableInfoArchive.self
                ) else { return nil }
                let tableModel = try graph.decode(tableInfo.tableModel, as: TST_TableModelArchive.self)
                let rows = try NumbersTableDecoder.rows(for: tableModel, graph: graph)
                return NumbersTable(name: tableModel.tableName, rows: rows)
            }

            return NumbersSheet(name: sheetArchive.name, tables: tables)
        }
    }

    public func sheet(named name: String) -> NumbersSheet? {
        sheets.first { $0.name == name }
    }
}
