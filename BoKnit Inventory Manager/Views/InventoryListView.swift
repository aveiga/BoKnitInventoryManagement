import SwiftUI
import SwiftData

struct InventoryListView: View {
    @Query(sort: [SortDescriptor(\InventoryItem.productName), SortDescriptor(\InventoryItem.colorName)])
    private var inventoryItems: [InventoryItem]

    @State private var searchText = ""
    @State private var showLowStockOnly = false
    @State private var isShowingImporter = false

    private static let lowStockThreshold = 2

    /// Euro value of everything on hand. Products the last import couldn't price
    /// contribute nothing, so this reads low rather than wrong when the
    /// "Produtos" sheet is missing a column.
    private var stockValue: Decimal {
        inventoryItems.reduce(Decimal.zero) { $0 + ($1.stockValue ?? 0) }
    }

    private var unpricedItemCount: Int {
        inventoryItems.count { $0.unitPrice == nil }
    }

    private var filteredItems: [InventoryItem] {
        inventoryItems
            .filter { showLowStockOnly ? $0.quantity <= Self.lowStockThreshold : true }
            .filter { searchText.isEmpty
                || $0.productName.localizedCaseInsensitiveContains(searchText)
                || $0.colorName.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        BKBrandRow()
                            .padding(.bottom, 14)
                        BKScreenTitleRow(title: "Inventory") {
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                Text("\(inventoryItems.count)")
                                    .bkStatNumber(size: 26)
                                    .foregroundStyle(BKColor.ink)
                                Text("skus").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                            }
                        }
                        BKTotalDisplay(
                            label: "stock value",
                            amount: BKCurrency.string(stockValue),
                            caption: unpricedItemCount > 0 ? "\(unpricedItemCount) unpriced" : nil
                        )
                        .padding(.top, 14)

                        Toggle(isOn: $showLowStockOnly.animation()) {
                            Text("low stock only").bkMonoLabel().foregroundStyle(BKColor.ink2)
                        }
                        .toggleStyle(BKInlineToggleStyle())
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(filteredItems) { item in
                    InventoryRowView(item: item)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BKColor.chassis)
            .overlay {
                if inventoryItems.isEmpty {
                    ContentUnavailableView(
                        "No Inventory Yet",
                        systemImage: "shippingbox",
                        description: Text("Import your Numbers spreadsheet to get started.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Product or color")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BKColor.chassis, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Import from Numbers…", systemImage: "square.and.arrow.down")
                    }
                    .tint(BKColor.orange)
                }
            }
            .sheet(isPresented: $isShowingImporter) {
                InventoryImportView()
            }
        }
    }
}

private struct BKInlineToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                BKSwitch(isOn: configuration.$isOn)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.panel2)
                    RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }
}
