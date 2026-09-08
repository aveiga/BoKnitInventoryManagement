import SwiftUI

struct PurchaseHistoryRowView: View {
    let purchase: Purchase

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 11) {
            Text(Self.timeFormatter.string(from: purchase.timestamp))
                .bkMonoLabel(size: 10)
                .foregroundStyle(BKColor.ink2)
                .fixedSize()

            RoundedRectangle(cornerRadius: 1.5)
                .fill(BKColorSwatch.color(for: purchase.colorName))
                .frame(width: 4, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(purchase.productName)
                    .bkRowTitle(size: 13)
                    .foregroundStyle(BKColor.ink)
                Text(buyerName.map { "\(purchase.colorName) · \($0)" } ?? purchase.colorName)
                    .bkMonoLabel(size: 9)
                    .foregroundStyle(BKColor.ink2)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(purchase.lineTotal.map(BKCurrency.string) ?? "—")
                    .bkMonoLabel(size: 11, weight: .bold)
                    .foregroundStyle(BKColor.ink)
                Text(purchase.unitPrice.map { "\(BKCurrency.string($0)) ea" } ?? "no price")
                    .bkMonoLabel(size: 8)
                    .foregroundStyle(BKColor.ink2)
            }
            .fixedSize()

            Text("×\(purchase.quantity)")
                .bkMonoLabel(size: 11, weight: .bold)
                .foregroundStyle(BKColor.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).fill(BKColor.panel2)
                        RoundedRectangle(cornerRadius: 2).strokeBorder(BKColor.line, lineWidth: 1)
                    }
                )
        }
        .padding(.horizontal, 13)
        .frame(height: 54)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
            }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var buyerName: String? {
        guard let name = purchase.buyerName, !name.isEmpty else { return nil }
        return name.lowercased()
    }
}
