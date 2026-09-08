import Foundation

enum PurchaseCSVExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func csv(for purchases: [Purchase]) -> Data {
        var lines = ["Date,Time,Product,Color,Buyer,Quantity,Unit Price EUR,Line Total EUR,Order"]
        for purchase in purchases {
            let fields = [
                dateFormatter.string(from: purchase.timestamp),
                timeFormatter.string(from: purchase.timestamp),
                purchase.productName,
                purchase.colorName,
                purchase.buyerName ?? "",
                "\(purchase.quantity)",
                purchase.unitPrice.map(BKCurrency.csvString) ?? "",
                purchase.lineTotal.map(BKCurrency.csvString) ?? "",
                purchase.purchaseGroupID?.uuidString ?? ""
            ]
            lines.append(fields.map(quoted).joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        return Data(csv.utf8)
    }

    static func filename(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "BoKnit_Purchases_\(formatter.string(from: date)).csv"
    }

    private static func quoted(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}
