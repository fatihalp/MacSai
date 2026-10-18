import Foundation

public enum MenuBarMetric: String, CaseIterable, Identifiable, Sendable {
    case diskFree = "diskFree"
    case gpuUsage = "gpuUsage"
    case memoryUsage = "memoryUsage"
    case batteryTemperature = "temperature"
    case iconOnly = "iconOnly"

    public static let defaultsKey = "menuBarMetric"
    public static let fallback: MenuBarMetric = .diskFree

    public var id: String { rawValue }

    public static func resolve(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? fallback
    }

    public var localizedName: String {
        switch self {
        case .diskFree:
            String(localized: "Free disk space")
        case .gpuUsage:
            String(localized: "GPU usage")
        case .memoryUsage:
            String(localized: "Memory usage")
        case .batteryTemperature:
            String(localized: "Battery temperature")
        case .iconOnly:
            String(localized: "Icon only")
        }
    }

    public func formattedValue(
        diskFree: UInt64,
        gpuUsage: Double?,
        memoryUsage: Double,
        batteryTemperature: Double?
    ) -> String? {
        switch self {
        case .diskFree:
            FileSizeFormatter.format(diskFree)
        case .gpuUsage:
            Self.formattedPercent(prefix: "GPU", value: gpuUsage)
        case .memoryUsage:
            Self.formattedPercent(prefix: "RAM", value: memoryUsage)
        case .batteryTemperature:
            Self.formattedTemperature(batteryTemperature)
        case .iconOnly:
            nil
        }
    }

    private static func formattedPercent(prefix: String, value: Double?) -> String {
        guard let value, value.isFinite else { return "\(prefix) --" }
        let percent = Int((min(max(value, 0), 1) * 100).rounded())
        return "\(prefix) \(percent)%"
    }

    private static func formattedTemperature(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0, value <= 120 else { return "--" }
        return "\(Int(value.rounded()))°C"
    }
}
