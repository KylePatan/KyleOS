import SwiftUI

/// Root sidebar/detail shell. Home is the default startup screen per Master PRD §3.
struct RootView: View {
    @State private var selection: SidebarDestination? = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarDestination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationTitle("Kyle OS")
            .frame(minWidth: 180)
        } detail: {
            PlaceholderDestinationView(destination: selection ?? .home)
        }
    }
}

#Preview {
    RootView()
}
