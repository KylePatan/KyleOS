import SwiftUI

/// Root sidebar/detail shell. Home is the default startup screen per Master PRD §3. Sidebar
/// selection lives on the shared `AppNavigationController` (not local `@State`) so cross-module
/// deep links (Home card -> a specific Writing/Stand Up/Clips/Sketches item) can switch sections
/// and set a pending target atomically from anywhere in the app.
struct RootView: View {
    @Environment(AppNavigationController.self) private var navigator

    var body: some View {
        @Bindable var navigator = navigator
        NavigationSplitView {
            List(selection: $navigator.selection) {
                Section("Kyle OS") {
                    ForEach(SidebarDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(SidebarSelection.destination(destination))
                    }
                }
                Section("Developer") {
                    ForEach(DevDestination.allCases) { dev in
                        Label(dev.title, systemImage: dev.systemImage)
                            .tag(SidebarSelection.dev(dev))
                    }
                }
            }
            .navigationTitle("Kyle OS")
            .frame(minWidth: 180)
        } detail: {
            switch navigator.selection ?? .destination(.home) {
            case .destination(.home):
                HomeView()
            case .destination(.writing):
                WritingHomeView()
            case .destination(.standUp):
                StandUpHomeView()
            case .destination(.clips):
                ClipsHomeView()
            case .destination(.sketches):
                SketchBoardView()
            case .destination(.calendar):
                CalendarHomeView()
            case .destination(.reports):
                ReportsView()
            case .destination(let destination):
                PlaceholderDestinationView(destination: destination)
            case .dev(.projects):
                ProjectsDevView()
            case .dev(.documents):
                DocumentsDevView()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.makeInMemoryContainer())
        .environment(FocusTimerController())
        .environment(AppNavigationController())
}
