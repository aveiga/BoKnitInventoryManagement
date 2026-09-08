import Foundation
import SwiftData

struct InventoryImportPreview {
    let rows: [InventoryRow]
    let newCount: Int
    let updatedCount: Int
    let unchangedCount: Int
    let removableCount: Int
    /// Distinct products in the file that the "Produtos" sheet priced.
    let pricedProductCount: Int
    /// Distinct products in the file with no matching "Produtos" column, sorted.
    let unpricedProductNames: [String]

    var productCount: Int { pricedProductCount + unpricedProductNames.count }
}

enum InventoryImportService {
    /// Compares parsed rows against what's currently stored, without writing anything.
    static func preview(rows: [InventoryRow], existingItems: [InventoryItem]) -> InventoryImportPreview {
        var existingByKey: [String: InventoryItem] = [:]
        for item in existingItems {
            existingByKey[key(item.productName, item.colorName)] = item
        }

        var newCount = 0
        var updatedCount = 0
        var unchangedCount = 0
        var seenKeys = Set<String>()
        var pricedProducts = Set<String>()
        var unpricedProducts = Set<String>()

        for row in rows {
            let rowKey = key(row.productName, row.colorName)
            seenKeys.insert(rowKey)
            if row.unitPrice == nil {
                unpricedProducts.insert(row.productName)
            } else {
                pricedProducts.insert(row.productName)
            }
            if let existing = existingByKey[rowKey] {
                if existing.quantity == row.quantity && existing.unitPrice == row.unitPrice {
                    unchangedCount += 1
                } else {
                    updatedCount += 1
                }
            } else {
                newCount += 1
            }
        }

        let removableCount = existingByKey.keys.filter { !seenKeys.contains($0) }.count

        return InventoryImportPreview(
            rows: rows,
            newCount: newCount,
            updatedCount: updatedCount,
            unchangedCount: unchangedCount,
            removableCount: removableCount,
            pricedProductCount: pricedProducts.count,
            unpricedProductNames: unpricedProducts.subtracting(pricedProducts).sorted()
        )
    }

    /// Upserts parsed rows into the store by (productName, colorName). Never deletes anything
    /// unless `removeMissing` is true, in which case existing items absent from `rows` are deleted.
    ///
    /// The file is the sole source of truth for both quantity and price, so a row
    /// that arrives without a price clears any price the item was carrying.
    static func apply(
        rows: [InventoryRow],
        removeMissing: Bool,
        context: ModelContext
    ) throws {
        let existingItems = try context.fetch(FetchDescriptor<InventoryItem>())
        var existingByKey: [String: InventoryItem] = [:]
        for item in existingItems {
            existingByKey[key(item.productName, item.colorName)] = item
        }

        var seenKeys = Set<String>()
        for row in rows {
            let rowKey = key(row.productName, row.colorName)
            seenKeys.insert(rowKey)
            if let existing = existingByKey[rowKey] {
                existing.quantity = row.quantity
                existing.unitPrice = row.unitPrice
                existing.lastUpdatedAt = .now
            } else {
                context.insert(InventoryItem(
                    productName: row.productName,
                    colorName: row.colorName,
                    quantity: row.quantity,
                    unitPrice: row.unitPrice
                ))
            }
        }

        if removeMissing {
            for (itemKey, item) in existingByKey where !seenKeys.contains(itemKey) {
                context.delete(item)
            }
        }

        try context.save()
    }

    private static func key(_ productName: String, _ colorName: String) -> String {
        "\(productName)\u{1}\(colorName)"
    }
}
