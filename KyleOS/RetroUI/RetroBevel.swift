import SwiftUI

/// The classic Windows beveled edge (spec §8): a lighter top/left line and a darker bottom/right
/// line, swapping when pressed to read as "inset." A single-color `strokeBorder` can't produce
/// this — it needs two distinct paths.
struct RetroBevel: View {
    var isPressed: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            }
            .stroke(isPressed ? RetroTheme.bevelDark : RetroTheme.bevelLight, lineWidth: RetroTheme.borderWidth)

            Path { path in
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
            .stroke(isPressed ? RetroTheme.bevelLight : RetroTheme.bevelDark, lineWidth: RetroTheme.borderWidth)
        }
        .allowsHitTesting(false)
    }
}
