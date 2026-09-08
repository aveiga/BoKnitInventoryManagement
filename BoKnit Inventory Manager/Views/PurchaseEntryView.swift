import SwiftUI
import SwiftData

struct PurchaseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\InventoryItem.productName), SortDescriptor(\InventoryItem.colorName)])
    private var inventoryItems: [InventoryItem]
    @Query(sort: \Purchase.timestamp, order: .reverse)
    private var purchases: [Purchase]

    /// One product+colour the shopper is buying. A purchase is a list of these,
    /// committed together as a single order.
    ///
    /// The line refers to its item by identifier rather than holding the model,
    /// so an import that removes an item while a purchase is half-built drops
    /// the line instead of leaving a dangling reference behind.
    private struct PurchaseLine: Identifiable {
        let id = UUID()
        let itemID: PersistentIdentifier
        var quantity: Int
    }

    /// A line paired with the item it points at, skipping lines whose item is
    /// no longer in the store.
    private struct ResolvedLine: Identifiable {
        let line: PurchaseLine
        let item: InventoryItem

        var id: UUID { line.id }
        var quantity: Int { line.quantity }
        var unitPrice: Decimal? { item.unitPrice }
        var total: Decimal? { item.unitPrice.map { $0 * Decimal(quantity) } }
    }

    @State private var lines: [PurchaseLine] = []
    @State private var selectedProductName: String?
    @State private var selectedColorName: String?
    @State private var quantity = 1
    @State private var buyerName = ""
    @State private var isShowingProductPicker = false
    @State private var toastMessage: String?
    @State private var confirmationTick = 0

    private var productNames: [String] {
        Array(Set(inventoryItems.map(\.productName))).sorted()
    }

    private var colorsForSelectedProduct: [InventoryItem] {
        guard let selectedProductName else { return [] }
        return inventoryItems
            .filter { $0.productName == selectedProductName }
            .sorted { $0.colorName < $1.colorName }
    }

    private var selectedInventoryItem: InventoryItem? {
        colorsForSelectedProduct.first { $0.colorName == selectedColorName }
    }

    private var resolvedLines: [ResolvedLine] {
        let itemsByID = Dictionary(
            inventoryItems.map { ($0.persistentModelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return lines.compactMap { line in
            itemsByID[line.itemID].map { ResolvedLine(line: line, item: $0) }
        }
    }

    /// Stock left for an item once what's already in the purchase is set aside,
    /// so two lines of the same product+colour can't oversell it between them.
    private func remainingStock(for item: InventoryItem) -> Int {
        let claimed = lines
            .filter { $0.itemID == item.persistentModelID }
            .reduce(0) { $0 + $1.quantity }
        return max(0, item.quantity - claimed)
    }

    private var maxQuantity: Int {
        guard let selectedInventoryItem else { return 0 }
        return remainingStock(for: selectedInventoryItem)
    }

    private var unitCount: Int {
        resolvedLines.reduce(0) { $0 + $1.quantity }
    }

    private var purchaseTotal: Decimal {
        resolvedLines.reduce(Decimal.zero) { $0 + ($1.total ?? 0) }
    }

    private var unpricedLineCount: Int {
        resolvedLines.count { $0.unitPrice == nil }
    }

    private var recentBuyerNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for purchase in purchases {
            guard let name = purchase.buyerName, !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
            if result.count == 6 { break }
        }
        return result
    }

    private var canAddLine: Bool {
        selectedInventoryItem != nil && quantity > 0 && quantity <= maxQuantity
    }

    private var canConfirm: Bool { !resolvedLines.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BKBrandRow()
                        .padding(.bottom, 14)

                    BKScreenTitleRow(title: "New Purchase") {
                        let lineCount = resolvedLines.count
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("in purchase")
                                .bkMonoLabel(size: 9)
                                .foregroundStyle(BKColor.ink2)
                            Text("\(lineCount) line\(lineCount == 1 ? "" : "s") · \(unitCount) units")
                                .bkMonoLabel(size: 9)
                                .foregroundStyle(lineCount == 0 ? BKColor.ink2 : BKColor.orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        productSection
                        colorSection
                        quantitySection
                        purchaseSection
                        buyerSection
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(BKColor.chassis)
            .safeAreaInset(edge: .bottom) {
                BKPrimaryButton(
                    title: canConfirm ? "Confirm · \(BKCurrency.string(purchaseTotal))" : "Confirm Purchase",
                    isDisabled: !canConfirm,
                    action: confirmPurchase
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(BKColor.chassis)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingProductPicker) {
                ProductPickerSheet(productNames: productNames) { name in
                    if name != selectedProductName {
                        selectedColorName = nil
                    }
                    selectedProductName = name
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    ToastBanner(message: toastMessage)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: selectedColorName) {
                quantity = min(1, maxQuantity)
            }
            .sensoryFeedback(trigger: selectedProductName) { _, newValue in
                newValue != nil ? .selection : nil
            }
            .sensoryFeedback(.selection, trigger: quantity)
            .sensoryFeedback(.impact, trigger: lines.count)
            .sensoryFeedback(.success, trigger: confirmationTick)
        }
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(index: 1, title: "product")

            Button {
                isShowingProductPicker = true
            } label: {
                HStack {
                    Text(selectedProductName ?? "Select a product")
                        .bkRowTitle(size: 16)
                        .foregroundStyle(selectedProductName == nil ? BKColor.ink2 : BKColor.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BKColor.ink2)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.line).offset(y: 2)
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                    RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                }
            )
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(index: 2, title: "colour", trailing: selectedColorName)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(colorsForSelectedProduct) { item in
                    let available = remainingStock(for: item)
                    BKSwatchTile(
                        swatch: BKColorSwatch.color(for: item.colorName),
                        label: String(format: "%02d", available),
                        isSelected: item.colorName == selectedColorName,
                        isEmpty: available <= 0
                    ) {
                        selectedColorName = item.colorName
                    }
                }
            }
        }
        .opacity(selectedProductName == nil ? 0.4 : 1)
        .disabled(selectedProductName == nil)
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(index: 3, title: "quantity", trailing: quantityTrailingLabel)

            HStack(spacing: 8) {
                BKKeyButton(systemImage: "minus", isDisabled: selectedColorName == nil || quantity <= 1) {
                    quantity = max(1, quantity - 1)
                }
                BKStepperDisplay(value: quantity)
                BKKeyButton(systemImage: "plus", isDisabled: selectedColorName == nil || quantity >= maxQuantity) {
                    quantity = min(maxQuantity, quantity + 1)
                }
            }
            .opacity(selectedColorName == nil ? 0.4 : 1)

            BKSecondaryButton(
                title: addLineTitle,
                systemImage: "plus",
                isDisabled: !canAddLine,
                action: addLine
            )
            .padding(.top, 2)
        }
    }

    private var quantityTrailingLabel: String? {
        guard let item = selectedInventoryItem else { return nil }
        let stock = "max \(maxQuantity)"
        guard let price = item.unitPrice else { return "no price · \(stock)" }
        return "\(BKCurrency.string(price)) ea · \(stock)"
    }

    private var addLineTitle: String {
        guard let item = selectedInventoryItem, quantity > 0,
              let price = item.unitPrice else { return "Add to purchase" }
        return "Add to purchase · \(BKCurrency.string(price * Decimal(quantity)))"
    }

    private var purchaseSection: some View {
        let currentLines = resolvedLines
        return VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(
                index: 4,
                title: "this purchase",
                trailing: currentLines.isEmpty ? nil : "\(unitCount) units"
            )

            if currentLines.isEmpty {
                HStack(spacing: 9) {
                    Rectangle().fill(BKColor.line).frame(width: 3, height: 22)
                    Text("Nothing added yet. Pick a product, colour, and quantity, then add it above.")
                        .font(.system(size: 12))
                        .foregroundStyle(BKColor.ink2)
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(currentLines) { line in
                        PurchaseLineRow(
                            productName: line.item.productName,
                            colorName: line.item.colorName,
                            quantity: line.quantity,
                            unitPrice: line.unitPrice,
                            total: line.total
                        ) {
                            withAnimation {
                                lines.removeAll { $0.id == line.id }
                            }
                        }
                    }
                }

                BKTotalDisplay(
                    label: "purchase total",
                    amount: BKCurrency.string(purchaseTotal),
                    caption: unpricedLineCount > 0
                        ? "\(unpricedLineCount) line\(unpricedLineCount == 1 ? "" : "s") unpriced"
                        : nil
                )
                .padding(.top, 2)
            }
        }
    }

    private var buyerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(index: 5, title: "bought by (opt)")

            TextField("Name", text: $buyerName)
                .bkRowTitle(size: 15)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                        RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                        HStack {
                            Rectangle().fill(BKColor.orange).frame(width: 2, height: 18)
                            Spacer()
                        }
                        .padding(.leading, 8)
                    }
                )

            if !recentBuyerNames.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(recentBuyerNames, id: \.self) { name in
                        Button {
                            buyerName = name
                        } label: {
                            BKTag(text: name.uppercased())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Moves the current product/colour/quantity selection into the purchase.
    /// Adding the same product+colour twice tops up the existing line rather
    /// than listing it twice.
    private func addLine() {
        guard let item = selectedInventoryItem, quantity > 0, quantity <= maxQuantity else { return }

        withAnimation {
            if let index = lines.firstIndex(where: { $0.itemID == item.persistentModelID }) {
                lines[index].quantity += quantity
            } else {
                lines.append(PurchaseLine(itemID: item.persistentModelID, quantity: quantity))
            }
        }

        // Keep the product selected — buying several colours of one product is
        // the common case — but clear the colour so the next pick starts fresh.
        selectedColorName = nil
        quantity = 1
    }

    private func confirmPurchase() {
        let committedLines = resolvedLines
        guard !committedLines.isEmpty else { return }

        let trimmedBuyer = buyerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = Date.now
        let groupID = UUID()
        let total = purchaseTotal
        let lineCount = committedLines.count

        for line in committedLines {
            line.item.quantity -= line.quantity
            line.item.lastUpdatedAt = timestamp
            modelContext.insert(Purchase(
                timestamp: timestamp,
                productName: line.item.productName,
                colorName: line.item.colorName,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                buyerName: trimmedBuyer.isEmpty ? nil : trimmedBuyer,
                purchaseGroupID: groupID,
                inventoryItem: line.item
            ))
        }
        confirmationTick += 1

        showToast("Recorded \(lineCount) line\(lineCount == 1 ? "" : "s") · \(BKCurrency.string(total))")

        lines = []
        selectedProductName = nil
        selectedColorName = nil
        quantity = 1
        buyerName = ""
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

/// One line of the purchase being built, with its unit price, line total, and a
/// key to take it back out.
private struct PurchaseLineRow: View {
    let productName: String
    let colorName: String
    let quantity: Int
    let unitPrice: Decimal?
    let total: Decimal?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(BKColorSwatch.color(for: colorName))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(productName)
                    .bkRowTitle(size: 13)
                    .foregroundStyle(BKColor.ink)
                    .lineLimit(1)
                Text(unitPrice.map { "\(colorName) · \(BKCurrency.string($0)) × \(quantity)" }
                    ?? "\(colorName) · no price × \(quantity)")
                    .bkMonoLabel(size: 9)
                    .foregroundStyle(unitPrice == nil ? BKColor.orange : BKColor.ink2)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(total.map(BKCurrency.string) ?? "—")
                .bkMonoLabel(size: 11, weight: .bold)
                .foregroundStyle(BKColor.ink)
                .fixedSize()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BKColor.ink2)
                    .frame(width: 30, height: 30)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 2).fill(BKColor.panel2)
                            RoundedRectangle(cornerRadius: 2).strokeBorder(BKColor.line, lineWidth: 1)
                        }
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(productName) \(colorName)")
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
            }
        )
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .bkMonoLabel(size: 11)
            .foregroundStyle(BKColor.insetInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
            .shadow(radius: 4)
    }
}

#Preview {
    PurchaseEntryView()
        .modelContainer(for: [InventoryItem.self, Purchase.self], inMemory: true)
}
