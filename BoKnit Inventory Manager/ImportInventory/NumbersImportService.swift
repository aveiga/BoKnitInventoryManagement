import Foundation
import NumbersKit

/// Adapts NumbersKit's raw table output into `InventoryRow`s for `InventoryImportService`.
///
/// The "Inventário" sheet is laid out as a cross-tab: row 0 holds product names
/// (starting at column 1), column 0 holds color names (starting at row 1), and
/// each remaining cell holds that product+color's quantity. Cells that aren't a
/// plain number (e.g. a "Sobra" note) are skipped rather than guessed at.
///
/// Unit prices come from the "Produtos" sheet, which is a cross-tab the other
/// way round: row 0 holds product names and column 0 labels each metric row
/// ("Gramas", "Custo Produto", "PVP", …). Only the "PVP" row is read.
struct NumbersImportService: InventoryFileParsing {
    static let inventorySheetName = "Inventário"
    static let productsSheetName = "Produtos"
    private static let retailPriceRowLabel = "PVP"
    private static let ignoredColorNames: Set<String> = ["TOTAL", "GANHO"]

    func parseInventory(from url: URL) throws -> [InventoryRow] {
        let document = try NumbersDocument(fileURL: url)
        guard let sheet = document.sheet(named: Self.inventorySheetName),
              let table = sheet.tables.first else {
            throw InventoryFileParsingError.sheetNotFound(Self.inventorySheetName)
        }

        let unitPrices = Self.unitPrices(in: document)

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
                    quantity: Int(quantity.rounded()),
                    unitPrice: unitPrices[Self.priceKey(productName)]
                ))
            }
        }
        return rows
    }

    /// Collects the "PVP" row from every table on the "Produtos" sheet, keyed by
    /// product name. Tables without a "PVP" row (e.g. "Consumíveis", which lists
    /// raw materials) contribute nothing.
    ///
    /// Products are matched to inventory by name alone — no aliases, no fuzzy
    /// matching — so a product spelled differently in "Inventário" than in
    /// "Produtos" simply comes back without a price rather than borrowing a
    /// neighbour's.
    private static func unitPrices(in document: NumbersDocument) -> [String: Decimal] {
        guard let sheet = document.sheet(named: productsSheetName) else { return [:] }

        var prices: [String: Decimal] = [:]
        for table in sheet.tables {
            guard let headerRow = table.rows.first else { continue }
            let productNames: [Int: String] = headerRow.enumerated().reduce(into: [:]) { result, item in
                let (column, value) = item
                guard column > 0, case .text(let name) = value, !name.isEmpty else { return }
                result[column] = name
            }
            guard !productNames.isEmpty else { continue }

            for row in table.rows.dropFirst() {
                guard let first = row.first, case .text(let label) = first,
                      label.trimmingCharacters(in: .whitespacesAndNewlines)
                          .caseInsensitiveCompare(retailPriceRowLabel) == .orderedSame
                else { continue }
                for (column, productName) in productNames {
                    guard column < row.count, case .number(let price) = row[column] else { continue }
                    prices[priceKey(productName)] = BKCurrency.decimal(fromSheetValue: price)
                }
            }
        }
        return prices
    }

    /// Trimmed, case-folded product name. Only stray whitespace and
    /// capitalisation are normalised away — names still have to be the same name.
    private static func priceKey(_ productName: String) -> String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
