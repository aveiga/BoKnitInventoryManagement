import Foundation
import NumbersKit

/// Adapts NumbersKit's raw table output into `InventoryRow`s for `InventoryImportService`.
///
/// The "Inventário" sheet is laid out as a cross-tab: row 0 holds product names
/// (starting at column 1), column 0 holds color names (starting at row 1), and
/// each remaining cell holds that product+color's quantity. Cells that aren't a
/// plain number (e.g. a "Sobra" note) are skipped rather than guessed at.
struct NumbersImportService: InventoryFileParsing {
    static let inventorySheetName = "Inventário"
    private static let ignoredColorNames: Set<String> = ["TOTAL", "GANHO"]

    func parseInventory(from url: URL) throws -> [InventoryRow] {
        let document = try NumbersDocument(fileURL: url)
        guard let sheet = document.sheet(named: Self.inventorySheetName),
              let table = sheet.tables.first else {
            throw InventoryFileParsingError.sheetNotFound(Self.inventorySheetName)
        }

        guard let headerRow = table.rows.first else { return [] }
        let productNames: [Int: String] = headerRow.enumerated().reduce(into: [:]) { result, item in
            let (column, value) = item
            guard column > 0, case .text(let name) = value, !name.isEmpty else { return }
            result[column] = name
        }

        var rows: [InventoryRow] = []
        for row in table.rows.dropFirst() {
            guard let first = row.first, case .text(let colorName) = first, !colorName.isEmpty,
                  !Self.ignoredColorNames.contains(colorName.trimmingCharacters(in: .whitespaces).uppercased())
            else { continue }
            for (column, productName) in productNames {
                guard column < row.count, case .number(let quantity) = row[column] else { continue }
                rows.append(InventoryRow(
                    productName: productName,
                    colorName: colorName,
                    quantity: Int(quantity.rounded())
                ))
            }
        }
        return rows
    }
}
