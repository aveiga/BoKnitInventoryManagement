import Foundation
import SwiftData

@Model
final class InventoryItem {
    #Unique<InventoryItem>([\.productName, \.colorName])

    var productName: String
    var colorName: String
    var quantity: Int
    var lastUpdatedAt: Date

    init(productName: String, colorName: String, quantity: Int, lastUpdatedAt: Date = .now) {
        self.productName = productName
        self.colorName = colorName
        self.quantity = quantity
        self.lastUpdatedAt = lastUpdatedAt
    }
}
