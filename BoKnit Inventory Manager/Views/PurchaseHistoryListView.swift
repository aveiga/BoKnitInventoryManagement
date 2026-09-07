import SwiftUI
import SwiftData

struct PurchaseHistoryListView: View {
    @Query(sort: \Purchase.timestamp, order: .reverse)
    private var purchases: [Purchase]

    @State private var searchText = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var isShowingDateFilter = false

    private var filteredPurchases: [Purchase] {
        purchases
            .filter { purchase in
                guard let startDate else { return true }
                return purchase.timestamp >= startDate
            }
            .filter { purchase in
                guard let endDate else { return true }
                return purchase.timestamp <= endDate
            }
            .filter { purchase in
                searchText.isEmpty
                    || purchase.productName.localizedCaseInsensitiveContains(searchText)
                    || purchase.colorName.localizedCaseInsensitiveContains(searchText)
                    || (purchase.buyerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
    }

    private var groupedByDay: [(day: Date, purchases: [Purchase])] {
        let groups = Dictionary(grouping: filteredPurchases) { purchase in
            Calendar.current.startOfDay(for: purchase.timestamp)
        }
        return groups.keys.sorted(by: >).map { day in (day: day, purchases: groups[day] ?? []) }
    }

    private var unitsOut: Int {
        filteredPurchases.reduce(0) { $0 + $1.quantity }
    }

    private var uniqueBuyerCount: Int {
        Set(filteredPurchases.compactMap { $0.buyerName?.isEmpty == false ? $0.buyerName : nil }).count
    }

    private var isDateFilterActive: Bool {
        startDate != nil || endDate != nil
    }

    private var exportFileURL: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(PurchaseCSVExporter.filename())
        try? PurchaseCSVExporter.csv(for: filteredPurchases).write(to: url)
        return url
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE dd MMM")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        BKBrandRow()
                            .padding(.bottom, 14)
                        BKScreenTitleRow(title: "Purchases") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("filtered").bkMonoLabel(size: 9).foregroundStyle(BKColor.ink2)
                                (Text("\(filteredPurchases.count)").foregroundColor(BKColor.ink)
                                    + Text(" of \(purchases.count)").foregroundColor(BKColor.ink2))
                                    .bkMonoLabel(size: 9)
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                isShowingDateFilter = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isDateFilterActive ? "calendar.badge.checkmark" : "calendar")
                                    Text(isDateFilterActive ? "Date range" : "Any date")
                                        .bkMonoLabel(size: 10, weight: .bold)
                                }
                                .foregroundStyle(isDateFilterActive ? .white : BKColor.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 3).fill(isDateFilterActive ? BKColor.orangeShadow : BKColor.line).offset(y: 2)
                                        RoundedRectangle(cornerRadius: 3).fill(isDateFilterActive ? BKColor.orange : BKColor.panel)
                                        RoundedRectangle(cornerRadius: 3).strokeBorder(isDateFilterActive ? BKColor.orange : BKColor.line, lineWidth: 1)
                                    }
                                )
                            }
                            .buttonStyle(.plain)

                            ShareLink(item: exportFileURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(BKColor.ink)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3).fill(BKColor.line).offset(y: 2)
                                            RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                                            RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                                        }
                                    )
                            }
                            .disabled(filteredPurchases.isEmpty)
                            .opacity(filteredPurchases.isEmpty ? 0.4 : 1)
                        }
                        .padding(.top, 14)

                        HStack(spacing: 0) {
                            statColumn(label: "units out", value: "\(unitsOut)")
                            Rectangle().fill(BKColor.insetLine).frame(width: 1).padding(.vertical, 12)
                            statColumn(label: "orders", value: "\(filteredPurchases.count)")
                            Rectangle().fill(BKColor.insetLine).frame(width: 1).padding(.vertical, 12)
                            statColumn(label: "buyers", value: "\(uniqueBuyerCount)")
                        }
                        .frame(height: 58)
                        .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
                        .padding(.top, 14)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.purchases) { purchase in
                            PurchaseHistoryRowView(purchase: purchase)
                        }
                    } header: {
                        HStack(spacing: 10) {
                            Text(Self.dayHeaderFormatter.string(from: group.day).lowercased())
                                .bkMonoLabel(size: 9)
                                .foregroundStyle(BKColor.ink2)
                            Rectangle().fill(BKColor.line).frame(height: 1)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BKColor.chassis)
            .overlay {
                if purchases.isEmpty {
                    ContentUnavailableView(
                        "No Purchases Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Purchases you register will show up here.")
                    )
                } else if filteredPurchases.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Product, color, or buyer")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BKColor.chassis, for: .navigationBar)
            .sheet(isPresented: $isShowingDateFilter) {
                DateRangeFilterSheet(startDate: $startDate, endDate: $endDate)
            }
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).bkMonoLabel(size: 8).foregroundStyle(BKColor.insetLabel)
            Text(value).bkStatNumber(size: 22).foregroundStyle(BKColor.insetInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 15)
    }
}

private struct DateRangeFilterSheet: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Environment(\.dismiss) private var dismiss

    @State private var isStartEnabled: Bool
    @State private var isEndEnabled: Bool
    @State private var start: Date
    @State private var end: Date

    init(startDate: Binding<Date?>, endDate: Binding<Date?>) {
        self._startDate = startDate
        self._endDate = endDate
        self._isStartEnabled = State(initialValue: startDate.wrappedValue != nil)
        self._isEndEnabled = State(initialValue: endDate.wrappedValue != nil)
        self._start = State(initialValue: startDate.wrappedValue ?? .now)
        self._end = State(initialValue: endDate.wrappedValue ?? .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BKScreenTitleRow(title: "Date Range") { EmptyView() }
                        .padding(.top, 6)

                    dateSection(index: 1, title: "from", isEnabled: $isStartEnabled, date: $start)
                        .padding(.top, 18)
                    dateSection(index: 2, title: "to", isEnabled: $isEndEnabled, date: $end)
                        .padding(.top, 18)

                    Spacer(minLength: 32)

                    BKPrimaryButton(title: "Apply Filter") {
                        startDate = isStartEnabled ? Calendar.current.startOfDay(for: start) : nil
                        endDate = isEndEnabled ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) : nil
                        dismiss()
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .background(BKColor.chassis)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BKColor.chassis, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(BKColor.ink2)
                }
            }
        }
    }

    private func dateSection(index: Int, title: String, isEnabled: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BKSectionLabel(index: index, title: title)
                Spacer()
                BKSwitch(isOn: isEnabled)
            }
            if isEnabled.wrappedValue {
                DatePicker("", selection: date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(BKColor.orange)
                    .colorScheme(.dark)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 3).fill(BKColor.inset))
            }
        }
    }
}
