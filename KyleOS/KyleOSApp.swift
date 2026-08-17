import SwiftUI
import SwiftData
import AppKit

@main
struct KyleOSApp: App {
    let container: ModelContainer
    /// One shared instance for the app's lifetime, injected into the environment below — PRD
    /// §4.8: "the timer continues while navigating elsewhere in Kyle OS." Any screen, not just
    /// Home, can observe/control it.
    @State private var timerController = FocusTimerController()
    /// One shared instance for the app's lifetime — owns sidebar selection and cross-module
    /// deep-linking (see AppNavigationController's own doc comment).
    @State private var navigationController = AppNavigationController()

    init() {
        // Kyle (2026-08-16): "I don't like this dark mode stuff" — white background, black/dark
        // blue writing, always. Forcing .aqua rather than just a SwiftUI-side override keeps
        // native chrome (title bar, standard controls, menus) light too, not just RetroTheme's
        // own custom-drawn surfaces. `NSApplication.shared`, not the `NSApp` global — under the
        // SwiftUI App lifecycle, `NSApp` is still nil this early during `init()`.
        NSApplication.shared.appearance = NSAppearance(named: .aqua)

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
                .environment(navigationController)
                .preferredColorScheme(.light)
                // Kyle (2026-08-16): "text a little bigger all over in general." One step above
                // the system default (.large) — applies app-wide via Dynamic Type, reaching every
                // screen immediately including modules not yet individually reskinned, rather
                // than hand-editing font sizes file by file.
                .dynamicTypeSize(.xLarge)
        }
        .modelContainer(container)

        // Kyle (2026-08-17): "I should be able to open ACT 1 scenes in a different window...
        // This should be the same for all items in all potential projects." A second WindowGroup
        // parameterized by `DetachedWindowTarget`, opened via `openWindow(value:)` from wherever
        // a "pop out" button lives (see ActOutlineView's ActRow) — shares the SAME `container` as
        // the main window, so it's a live second view onto one store, not a separate copy.
        WindowGroup(id: "detached", for: DetachedWindowTarget.self) { $target in
            if let target {
                DetachedWindowRootView(target: target)
                    .environment(timerController)
                    .environment(navigationController)
                    .preferredColorScheme(.light)
                    .dynamicTypeSize(.xLarge)
            }
        }
        .modelContainer(container)
    }
}
