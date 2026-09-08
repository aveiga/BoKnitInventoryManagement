import Foundation
import SwiftData

@Model
final class InventoryItem {
    #Unique<InventoryItem>([\.productName, \.colorName])

    var productName: String
    var colorName: String
    var quantity: Int
    /// Retail price (PVP) per unit in euro, as of the last import. `nil` when the
    /// imported file's "Produtos" sheet had no price for this product.
    var unitPrice: Decimal?
    var lastUpdatedAt: Date

    init(
        productName: String,
        colorName: String,
        quantity: Int,
        unitPrice: Decimal? = nil,
        lastUpdatedAt: Date = .now
    ) {
        self.productName = productName
        self.colorName = colorName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lastUpdatedAt = lastUpdatedAt
    }

    /// Euro value of the stock on hand for this product+colour.
    var stockValue: Decimal? {
        unitPrice.map { $0 * Decimal(max(0, quantity)) }
    }
}
