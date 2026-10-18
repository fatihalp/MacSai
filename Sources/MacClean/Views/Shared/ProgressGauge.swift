import SwiftUI
import AppKit
import MacCleanKit

public struct ProgressGauge: View {
    let value: Double
    let label: String
    let detail: String
    let color: Color

    public init(value: Double, label: String, detail: String, color: Color = Color(nsColor: .systemBlue)) {
        self.value = min(max(value, 0), 1)
        self.label = label
        self.detail = detail
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: value)

                VStack(spacing: 2) {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 76, height: 76)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

public struct SizeDisplay: View {
    let bytes: UInt64
    let subtitle: String

    public init(size bytes: UInt64, label subtitle: String = String(localized: "can be cleaned")) {
        self.bytes = bytes
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                let parts = formattedParts
                Text(parts.number)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.default, value: bytes)
                Text(parts.unit)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var formattedParts: (number: String, unit: String) {
        let formatted = FileSizeFormatter.format(bytes)
        let components = formatted.split(separator: " ", maxSplits: 1)
        if components.count == 2 {
            return (String(components[0]), String(components[1]))
        }
        return (formatted, "")
    }
}

public struct ScanProgressRing: View {
    let progress: Double
    let phase: String
    let detail: String?
    let theme: ModuleTheme

    public init(progress: Double, phase: String, detail: String? = nil, theme: ModuleTheme = .smartScan) {
        self.progress = min(max(progress, 0), 1)
        self.phase = phase
        self.detail = detail
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(theme.accentColor)
                .frame(width: 260)

            VStack(spacing: 4) {
                Text("\(Int(progress * 100))% · \(phase)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 340)

                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
    }
}
