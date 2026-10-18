import SwiftUI
import AppKit

public struct ScanButton: View {
    let title: String
    let subtitle: String?
    let theme: ModuleTheme
    let action: () -> Void

    public init(
        title: String = "Scan",
        subtitle: String? = nil,
        theme: ModuleTheme,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(minWidth: 110)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accentColor)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
}
