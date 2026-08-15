import SwiftUI
import AppKit

/// Kyle (2026-08-15): "Kyle OS interface = retro computer system. Creative writing surface =
/// classic typewriter / writer's page." The actual creative-writing surfaces — screenplay text,
/// prose, jokes/chunks/headline-set material — use a classic typewriter-style monospace font,
/// visually similar to Courier/Courier Prime (the typeface long associated with screenplay and
/// manuscript software), while everything organizational (titles, status, timestamps, drag
/// handles, buttons) stays in the system font. That distinction is drawn per-field at each call
/// site, not by theme-wide override — most of Kyle OS's surrounding chrome deliberately doesn't
/// use this.
///
/// Uses macOS's built-in Courier rather than bundling Courier Prime as a custom font resource —
/// same visual family, immediately available, no font-licensing/bundling question to resolve now.
/// If Kyle wants the exact Courier Prime typeface later, that's a font file to add to the app
/// bundle and register — this is the one place that would need to change.
enum WritingSurfaceFont {
    static func swiftUI(size: CGFloat = 13) -> Font {
        .custom("Courier", size: size)
    }

    static func nsFont(size: CGFloat = 12) -> NSFont {
        NSFont(name: "Courier", size: size) ?? NSFont.userFixedPitchFont(ofSize: size)!
    }
}
