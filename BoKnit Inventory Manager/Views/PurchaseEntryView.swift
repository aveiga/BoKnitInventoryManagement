import SwiftUI
import SwiftData

struct PurchaseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\InventoryItem.productName), SortDescriptor(\InventoryItem.colorName)])
    private var inventoryItems: [InventoryItem]
    @Query(sort: \Purchase.timestamp, order: .reverse)
    private var purchases: [Purchase]

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

    private var maxQuantity: Int {
        max(0, selectedInventoryItem?.quantity ?? 0)
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

    private var canConfirm: Bool {
        selectedProductName != nil && selectedColorName != nil && quantity > 0
    }

    private var completedStepCount: Int {
        var count = 0
        if selectedProductName != nil { count += 1 }
        if selectedColorName != nil { count += 1 }
        if quantity > 0 { count += 1 }
        if !buyerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BKBrandRow()
                        .padding(.bottom, 14)

                    BKScreenTitleRow(title: "New Purchase") {
                        Text("STEP \(completedStepCount)/4")
                            .bkMonoLabel()
                            .foregroundStyle(BKColor.orange)
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        productSection
                        colorSection
                        quantitySection
                        buyerSection
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(BKColor.chassis)
            .safeAreaInset(edge: .bottom) {
                BKPrimaryButton(title: "Confirm Purchase", isDisabled: !canConfirm, action: confirmPurchase)
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
                    BKSwatchTile(
                        swatch: BKColorSwatch.color(for: item.colorName),
                        label: String(format: "%02d", max(0, item.quantity)),
                        isSelected: item.colorName == selectedColorName,
                        isEmpty: item.quantity <= 0
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
            BKSectionLabel(index: 3, title: "quantity", trailing: selectedColorName != nil ? "max \(maxQuantity)" : nil)

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
        }
    }

    private var buyerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            BKSectionLabel(index: 4, title: "bought by (opt)")

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

    private func confirmPurchase() {
        guard let selectedProductName, let selectedColorName else { return }

        let matchedItem = selectedInventoryItem
        matchedItem?.quantity -= quantity
        matchedItem?.lastUpdatedAt = .now

        let trimmedBuyer = buyerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let purchase = Purchase(
            productName: selectedProductName,
            colorName: selectedColorName,
            quantity: quantity,
            buyerName: trimmedBuyer.isEmpty ? nil : trimmedBuyer,
            inventoryItem: matchedItem
        )
        modelContext.insert(purchase)
        confirmationTick += 1

        let quantityDescription: String
        if let quantity = matchedItem?.quantity {
            quantityDescription = " · \(selectedColorName) now at \(quantity)"
        } else {
            quantityDescription = ""
        }
        showToast("Recorded: \(selectedProductName)\(quantityDescription)")

        self.selectedProductName = nil
        self.selectedColorName = nil
        self.quantity = 1
        self.buyerName = ""
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
