import SwiftUI

/// Root sidebar/detail shell. Home is the default startup screen per Master PRD §3.
struct RootView: View {
    @State private var selection: SidebarSelection? = .destination(.home)

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
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
            switch selection ?? .destination(.home) {
            case .destination(.home):
                HomeView()
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
}
