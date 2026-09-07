import Foundation

struct InventoryRow: Sendable, Equatable {
    let productName: String
    let colorName: String
    let quantity: Int
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
