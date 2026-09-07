import SwiftUI

struct ProductPickerSheet: View {
    let productNames: [String]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredNames: [String] {
        guard !searchText.isEmpty else { return productNames }
        return productNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("select").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                            Text("Product").font(.system(size: 22, weight: .heavy)).tracking(-0.4).foregroundStyle(BKColor.ink)
                        }
                        Spacer()
                        Text("\(productNames.count) products").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 10)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(Array(filteredNames.enumerated()), id: \.element) { index, name in
                    Button {
                        onSelect(name)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .bkMonoLabel(size: 10)
                                .foregroundStyle(BKColor.ink2)
                            Text(name)
                                .bkRowTitle(size: 15)
                                .foregroundStyle(BKColor.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 52)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                                RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 3, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BKColor.chassis)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BKColor.chassis, for: .navigationBar)
            .searchable(text: $searchText)
            .overlay {
                if productNames.isEmpty {
                    ContentUnavailableView(
                        "No Products Yet",
                        systemImage: "shippingbox",
                        description: Text("Import inventory from a Numbers file first.")
                    )
                }
            }
        }
    }
}
