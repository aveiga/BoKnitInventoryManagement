import Foundation
import SwiftData

struct InventoryImportPreview {
    let rows: [InventoryRow]
    let newCount: Int
    let updatedCount: Int
    let unchangedCount: Int
    let removableCount: Int
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

        for row in rows {
            let rowKey = key(row.productName, row.colorName)
            seenKeys.insert(rowKey)
            if let existing = existingByKey[rowKey] {
                if existing.quantity == row.quantity {
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
            removableCount: removableCount
        )
    }

    /// Upserts parsed rows into the store by (productName, colorName). Never deletes anything
    /// unless `removeMissing` is true, in which case existing items absent from `rows` are deleted.
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
                existing.lastUpdatedAt = .now
            } else {
                context.insert(InventoryItem(
                    productName: row.productName,
                    colorName: row.colorName,
                    quantity: row.quantity
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
