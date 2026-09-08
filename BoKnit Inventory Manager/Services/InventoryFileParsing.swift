import Foundation

struct InventoryRow: Sendable, Equatable {
    let productName: String
    let colorName: String
    let quantity: Int
    /// Retail price (PVP) per unit, read from the "Produtos" sheet. `nil` when
    /// that sheet has no column whose name matches this product.
    let unitPrice: Decimal?

    init(productName: String, colorName: String, quantity: Int, unitPrice: Decimal? = nil) {
        self.productName = productName
        self.colorName = colorName
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

enum InventoryFileParsingError: Error, LocalizedError {
    case sheetNotFound(String)
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .sheetNotFound(let name):
            return "Couldn't find a sheet named \"\(name)\" in this file."
        case .unsupportedFile:
            return "Couldn't read this file. Make sure it's a Numbers spreadsheet."
        }
    }
}

/// Abstraction over reading inventory rows out of an uploaded spreadsheet file.
/// Backed by NumbersKit's native `.numbers` parser.
protocol InventoryFileParsing {
    func parseInventory(from url: URL) throws -> [InventoryRow]
}
