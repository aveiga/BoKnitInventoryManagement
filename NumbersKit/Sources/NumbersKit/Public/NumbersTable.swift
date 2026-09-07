import Foundation

public struct NumbersTable {
    public let name: String
    public let rows: [[NumbersCellValue]]

    public var numberOfColumns: Int { rows.first?.count ?? 0 }
}

public struct NumbersSheet {
    public let name: String
    public let tables: [NumbersTable]
}
