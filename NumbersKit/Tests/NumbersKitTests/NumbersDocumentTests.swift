import Foundation
import Testing
@testable import NumbersKit

@Test func parsesInventarioSheetFromRealFile() throws {
    let fixtureURL = Bundle.module.url(forResource: "Produtos_Final", withExtension: "numbers", subdirectory: "Fixtures")!
    let document = try NumbersDocument(fileURL: fixtureURL)

    print("Sheets found: \(document.sheets.map(\.name))")
    for sheet in document.sheets {
        for table in sheet.tables {
            print("Sheet '\(sheet.name)' table '\(table.name)': \(table.rows.count) rows x \(table.numberOfColumns) cols")
        }
    }

    let sheet = try #require(document.sheet(named: "Inventário"))
    #expect(!sheet.tables.isEmpty)

    let table = sheet.tables[0]
    print("First table rows (up to 15):")
    for row in table.rows.prefix(15) {
        print(row.map(describe))
    }
}

private func describe(_ value: NumbersCellValue) -> String {
    switch value {
    case .empty: return "<empty>"
    case .text(let s): return "\"\(s)\""
    case .number(let n): return "\(n)"
    case .date(let d): return "\(d)"
    case .bool(let b): return "\(b)"
    case .error: return "<error>"
    }
}
