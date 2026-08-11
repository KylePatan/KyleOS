import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Kyle OS")
                .font(.largeTitle)
            Text("V0 Foundation — app shell")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding()
    }
}

#Preview {
    ContentView()
}
