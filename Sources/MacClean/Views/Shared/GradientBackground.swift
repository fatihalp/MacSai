import SwiftUI
import AppKit

extension Color {
    init(light: Color, dark: Color) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}

public enum ModuleTheme {
    case smartScan
    case cleanup
    case protection
    case performance
    case applications
    case files
    case settings

    public var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    public var buttonGradient: LinearGradient {
        LinearGradient(colors: buttonColors, startPoint: .top, endPoint: .bottom)
    }

    public var colors: [Color] {
        [Color.white, Color.white]
    }

    public var buttonColors: [Color] {
        [Color(nsColor: .systemBlue), Color(nsColor: .systemBlue)]
    }

    public var accentColor: Color {
        Color(nsColor: .systemBlue)
    }
}

public struct GradientBackgroundView: View {
    let theme: ModuleTheme

    public init(theme: ModuleTheme) {
        self.theme = theme
    }

    public var body: some View {
        Color.white
    }
}
