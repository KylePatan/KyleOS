import SwiftUI
import SwiftData

@main
struct KyleOSApp: App {
    let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
