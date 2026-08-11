import SwiftUI
import SwiftData

@main
struct KyleOSApp: App {
    let container: ModelContainer
    /// One shared instance for the app's lifetime, injected into the environment below — PRD
    /// §4.8: "the timer continues while navigating elsewhere in Kyle OS." Any screen, not just
    /// Home, can observe/control it.
    @State private var timerController = FocusTimerController()

    init() {
        let container = PersistenceController.makeContainer()
        self.container = container

        // Foundation baseline data must exist from first launch, not appear ad hoc the first
        // time some future screen happens to touch it.
        let context = container.mainContext
        do {
            try SettingsService.currentSettings(in: context)
            try WorkTypeDefaultService.seedKnownDefaultsIfNeeded(in: context)
            try context.save()
        } catch {
            assertionFailure("Failed to seed Foundation defaults: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timerController)
        }
        .modelContainer(container)
    }
}
