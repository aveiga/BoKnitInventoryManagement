import SwiftUI
import SwiftData

@main
struct BoKnitInventoryManagerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([InventoryItem.self, Purchase.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
