import Foundation
import SwiftData

@Model
final class Purchase {
    var timestamp: Date
    var productName: String
    var colorName: String
    var quantity: Int = 1
    /// Unit price in euro, snapshotted when the purchase was recorded, so past
    /// totals don't move when a later import changes the spreadsheet's PVP.
    var unitPrice: Decimal?
    var buyerName: String?
    /// Shared by every line recorded together, so a multi-product purchase
    /// counts as one order rather than one per product. `nil` for purchases
    /// recorded before multi-product purchases existed.
    var purchaseGroupID: UUID?
    @Relationship(deleteRule: .nullify)
    var inventoryItem: InventoryItem?

    init(
        timestamp: Date = .now,
        productName: String,
        colorName: String,
        quantity: Int = 1,
        unitPrice: Decimal? = nil,
        buyerName: String? = nil,
        purchaseGroupID: UUID? = nil,
        inventoryItem: InventoryItem? = nil
    ) {
        self.timestamp = timestamp
        self.productName = productName
        self.colorName = colorName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.buyerName = buyerName
        self.purchaseGroupID = purchaseGroupID
        self.inventoryItem = inventoryItem
    }

    /// What this line came to: unit price × quantity. `nil` when the product had
    /// no price at the time of purchase.
    var lineTotal: Decimal? {
        unitPrice.map { $0 * Decimal(quantity) }
    }
}
