import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inventoryItems: [InventoryItem]
    @Query private var purchases: [Purchase]

    @State private var pendingReset: PendingReset?
    @State private var errorMessage: String?

    private enum PendingReset: Identifiable {
        case inventory
        case purchases

        var id: Self { self }

        var title: String {
            switch self {
            case .inventory: return "Clear All Inventory?"
            case .purchases: return "Clear All Purchase History?"
            }
        }

        var message: String {
            switch self {
            case .inventory: return "This permanently deletes all inventory items. Purchase history is not affected. This cannot be undone."
            case .purchases: return "This permanently deletes all purchase records. Inventory is not affected. This cannot be undone."
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BKBrandRow(trailing: "service")
                        .padding(.bottom, 14)
                    BKScreenTitleRow(title: "Settings") { EmptyView() }

                    VStack(alignment: .leading, spacing: 8) {
                        BKSectionLabel(index: 1, title: "stored records")
                        HStack(spacing: 8) {
                            BKStatTile(label: "inventory items", value: "\(inventoryItems.count)")
                            BKStatTile(label: "purchase records", value: "\(purchases.count)")
                        }
                    }
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            BKSectionLabel(index: 2, title: "reset")
                            Spacer()
                            Text("irreversible")
                                .bkMonoLabel(size: 9, weight: .bold)
                                .foregroundStyle(BKColor.redText)
                        }

                        BKHazardStripe()

                        destructiveRow(
                            title: "Clear all inventory",
                            detail: "\(inventoryItems.count) items"
                        ) {
                            pendingReset = .inventory
                        }

                        destructiveRow(
                            title: "Clear purchase history",
                            detail: "\(purchases.count) records"
                        ) {
                            pendingReset = .purchases
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Rectangle().fill(BKColor.line).frame(width: 3)
                            Text("These actions are independent of each other and cannot be undone.")
                                .font(.system(size: 12))
                                .foregroundStyle(BKColor.ink2)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 40)

                    HStack {
                        Text("boknit inventory mgr").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().fill(BKColor.line).frame(width: 5, height: 5)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .background(BKColor.chassis)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                pendingReset?.title ?? "",
                isPresented: Binding(
                    get: { pendingReset != nil },
                    set: { if !$0 { pendingReset = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingReset
            ) { reset in
                Button("Delete Everything", role: .destructive) {
                    perform(reset)
                }
            } message: { reset in
                Text(reset.message)
            }
            .alert("Something Went Wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func destructiveRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(BKColor.red)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).bkRowTitle(size: 14).foregroundStyle(BKColor.ink)
                    Text(detail).bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 62)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.red).offset(y: 2)
                    RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                    RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.red, lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func perform(_ reset: PendingReset) {
        do {
            switch reset {
            case .inventory:
                try modelContext.delete(model: InventoryItem.self)
            case .purchases:
                try modelContext.delete(model: Purchase.self)
            }
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
