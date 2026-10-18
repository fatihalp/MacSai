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
        [accentColor, accentColor]
    }

    public var accentColor: Color {
        switch self {
        case .smartScan:
            Color(nsColor: .systemIndigo)
        case .cleanup:
            Color(nsColor: .systemBlue)
        case .protection:
            Color(nsColor: .systemGreen)
        case .performance:
            Color(nsColor: .systemOrange)
        case .applications:
            Color(nsColor: .systemRed)
        case .files:
            Color(nsColor: .systemTeal)
        case .settings:
            Color(nsColor: .systemGray)
        }
    }

    public var icon: String {
        switch self {
        case .smartScan: "sparkles"
        case .cleanup: "trash.fill"
        case .protection: "shield.fill"
        case .performance: "gauge.with.dots.needle.67percent"
        case .applications: "square.stack.3d.up.fill"
        case .files: "doc.fill"
        case .settings: "gearshape.fill"
        }
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
