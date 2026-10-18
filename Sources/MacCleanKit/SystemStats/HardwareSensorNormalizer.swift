import Foundation

public enum HardwareSensorNormalizer {
    public static let gpuUtilizationKeys = [
        "Device Utilization %",
        "GPU Activity(%)",
        "Renderer Utilization %",
    ]

    public static let batteryTemperatureKeys = [
        "Temperature",
        "VirtualTemperature",
    ]

    public static func gpuUsageFraction(from samples: [[String: NSNumber]]) -> Double? {
        var maximumPercent: Double?

        for sample in samples {
            for key in gpuUtilizationKeys {
                guard let number = sample[key] else { continue }
                let percent = number.doubleValue
                guard percent.isFinite else { continue }
                maximumPercent = max(maximumPercent ?? 0, min(max(percent, 0), 100))
            }
        }

        return maximumPercent.map { $0 / 100 }
    }

    public static func batteryTemperatureCelsius(
        from properties: [String: NSNumber]
    ) -> Double? {
        for key in batteryTemperatureKeys {
            guard let rawValue = properties[key],
                  let temperature = batteryTemperatureCelsius(fromRawValue: rawValue) else {
                continue
            }
            return temperature
        }
        return nil
    }

    public static func batteryTemperatureCelsius(fromRawValue rawValue: NSNumber) -> Double? {
        let raw = rawValue.doubleValue
        guard raw.isFinite else { return nil }

        let celsius: Double
        if raw >= 1_000 {
            celsius = raw / 100
        } else if raw > 120 {
            celsius = raw / 10
        } else {
            celsius = raw
        }

        guard celsius > 0, celsius <= 120 else { return nil }
        return celsius
    }
}
