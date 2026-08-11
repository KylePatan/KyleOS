import SwiftUI

struct PlaceholderDestinationView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(destination.title)
                .font(.largeTitle)
            Text(destination.roadmapNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(destination.title)
    }
}

#Preview {
    PlaceholderDestinationView(destination: .home)
}
