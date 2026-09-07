import SwiftUI

struct InventoryRowView: View {
    let item: InventoryItem

    private var isLowOrOut: Bool {
        item.quantity <= 2
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(BKColorSwatch.color(for: item.colorName))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName)
                    .bkRowTitle(size: 14)
                    .foregroundStyle(BKColor.ink)
                Text(item.quantity <= 0 ? "\(item.colorName) · out" : (isLowOrOut ? "\(item.colorName) · low" : item.colorName))
                    .bkMonoLabel(size: 9)
                    .foregroundStyle(isLowOrOut ? BKColor.orange : BKColor.ink2)
            }

            Spacer()

            BKDimmedNumber(
                value: max(0, item.quantity),
                minDigits: 2,
                size: 22,
                brightColor: isLowOrOut ? BKColor.orange : BKColor.ink
            )
        }
        .padding(.horizontal, 13)
        .frame(height: 56)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                if isLowOrOut {
                    HStack {
                        RoundedRectangle(cornerRadius: 1.5).fill(BKColor.orange).frame(width: 3)
                        Spacer()
                    }
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
