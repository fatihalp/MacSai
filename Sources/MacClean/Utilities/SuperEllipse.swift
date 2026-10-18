import SwiftUI
import AppKit

public struct SuperEllipseShape: Shape {
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}

public struct SuperEllipseButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let size: CGSize

    public init(gradient: LinearGradient, size: CGSize = CGSize(width: 140, height: 34)) {
        self.gradient = gradient
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .systemBlue))
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
