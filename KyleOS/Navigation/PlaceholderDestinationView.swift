import SwiftUI

struct PlaceholderDestinationView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: RetroTheme.controlSpacing) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(RetroTheme.secondaryText)
            Text(destination.title)
                .font(.largeTitle)
                .foregroundStyle(RetroTheme.primaryText)
            Text(destination.roadmapNote)
                .foregroundStyle(RetroTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RetroTheme.background)
        .navigationTitle(destination.title)
    }
}

#Preview {
    PlaceholderDestinationView(destination: .home)
}
