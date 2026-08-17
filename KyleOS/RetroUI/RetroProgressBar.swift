import SwiftUI

/// A thin bordered fill bar — one of the spec's own suggested component list (§31,
/// "RetroProgressBar"), not built until a screen actually needed one (per this design system's
/// established "build these ONCE, reuse everywhere, only when needed" discipline). First used by
/// `WeeklyBoardView`'s cards (Kyle, 2026-08-17: "a percentage completed bar so that when you look
/// at the home tasks - you can decipher... how much is done").
struct RetroProgressBar: View {
    /// 0...100. Values outside that range are clamped rather than trusted, since this always
    /// renders whatever `WorkItem.progress` currently holds.
    let percent: Int

    private var fraction: Double {
        min(max(Double(percent), 0), 100) / 100
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(RetroTheme.insetBackground)
                Rectangle()
                    .fill(RetroTheme.accent)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .overlay(Rectangle().strokeBorder(RetroTheme.border, lineWidth: RetroTheme.borderWidth))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: RetroTheme.controlSpacing) {
        RetroProgressBar(percent: 0)
        RetroProgressBar(percent: 35)
        RetroProgressBar(percent: 100)
    }
    .padding()
    .frame(width: 200)
}
