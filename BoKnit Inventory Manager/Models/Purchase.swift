import Foundation
import SwiftData

@Model
final class Purchase {
    var timestamp: Date
    var productName: String
    var colorName: String
    var quantity: Int = 1
    var buyerName: String?
    @Relationship(deleteRule: .nullify)
    var inventoryItem: InventoryItem?

    init(
        timestamp: Date = .now,
        productName: String,
        colorName: String,
        quantity: Int = 1,
        buyerName: String? = nil,
        inventoryItem: InventoryItem? = nil
    ) {
        self.timestamp = timestamp
        self.productName = productName
        self.colorName = colorName
        self.quantity = quantity
        self.buyerName = buyerName
        self.inventoryItem = inventoryItem
    }
}
