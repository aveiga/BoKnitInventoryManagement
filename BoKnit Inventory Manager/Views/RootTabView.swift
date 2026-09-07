import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootTabView: View {
    init() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BKColor.panel2)
        appearance.shadowColor = UIColor(BKColor.line)
        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(BKColor.ink2)
        normal.titleTextAttributes = [.foregroundColor: UIColor(BKColor.ink2)]
        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(BKColor.orange)
        selected.titleTextAttributes = [.foregroundColor: UIColor(BKColor.orange)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

    var body: some View {
        TabView {
            Tab("Purchase", systemImage: "cart.badge.plus") {
                PurchaseEntryView()
            }
            Tab("Inventory", systemImage: "shippingbox") {
                InventoryListView()
            }
            Tab("Purchases", systemImage: "list.bullet.clipboard") {
                PurchaseHistoryListView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(BKColor.orange)
    }
}
