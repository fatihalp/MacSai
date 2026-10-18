import SwiftUI
import AppKit
import MacCleanKit

struct HomeDashboardView: View {
    @Environment(AppState.self) private var appState
    let onStartScan: () -> Void

    @State private var specs: SystemHardwareSpecs = SystemSpecsProvider.current()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                systemHeaderCard
                smartScanHeroCard
                featuresSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                specs = SystemSpecsProvider.current()
            }
        }
    }

    private var systemHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .systemGray).opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: hardwareIcon)
                        .font(.system(size: 26))
                        .foregroundStyle(Color(nsColor: .labelColor))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(specs.modelName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(specs.chipName) · \(specs.cpuCores) Cores · \(specs.osVersion)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let level = specs.batteryLevel {
                    HStack(spacing: 6) {
                        Image(systemName: specs.isCharging ? "battery.100percent.bolt" : "battery.100percent")
                            .font(.system(size: 14))
                            .foregroundStyle(specs.isCharging ? Color(nsColor: .systemGreen) : Color.secondary)
                        Text("\(level)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
                }
            }

            Divider()

            HStack(spacing: 24) {
                hardwareMetric(
                    title: "Memory",
                    value: specs.memoryTotalFormatted,
                    detail: "\(specs.memoryUsedFormatted) used (\(Int(specs.memoryUsedFraction * 100))%)",
                    fraction: specs.memoryUsedFraction,
                    tint: Color(nsColor: .systemBlue)
                )

                hardwareMetric(
                    title: "Storage",
                    value: specs.diskTotalFormatted,
                    detail: "\(specs.diskFreeFormatted) available",
                    fraction: specs.diskUsedFraction,
                    tint: Color(nsColor: .systemIndigo)
                )

                hardwareMetric(
                    title: "Uptime",
                    value: uptimeFormatted,
                    detail: "Active & running",
                    fraction: nil,
                    tint: Color(nsColor: .systemGreen)
                )
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private var smartScanHeroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .systemIndigo))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Scan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("One-click comprehensive analysis of junk files, malware threats, and performance issues.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Start Scan", action: onStartScan)
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .systemIndigo))
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .background(Color(nsColor: .systemIndigo).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .systemIndigo).opacity(0.2), lineWidth: 1)
        )
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Features")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                featureCard(
                    item: .systemJunk,
                    title: "System Junk & Trash",
                    description: "Remove caches, logs, mail attachments, and empty trash bins.",
                    icon: "trash.fill",
                    color: Color(nsColor: .systemBlue)
                )

                featureCard(
                    item: .malwareRemoval,
                    title: "Protection & Privacy",
                    description: "Scan for threats, review permissions, and clear saved Wi-Fi networks.",
                    icon: "shield.fill",
                    color: Color(nsColor: .systemGreen)
                )

                featureCard(
                    item: .optimization,
                    title: "Performance & RAM",
                    description: "Monitor memory pressure, manage startup items, and run maintenance tasks.",
                    icon: "gauge.with.dots.needle.67percent",
                    color: Color(nsColor: .systemOrange)
                )

                featureCard(
                    item: .uninstaller,
                    title: "Apps & Updates",
                    description: "Completely uninstall apps, detect unused programs, and apply updates.",
                    icon: "xmark.app.fill",
                    color: Color(nsColor: .systemRed)
                )

                featureCard(
                    item: .spaceLens,
                    title: "Space Lens & Files",
                    description: "Visualize folder sizes, find duplicate files, and securely shred items.",
                    icon: "chart.pie.fill",
                    color: Color(nsColor: .systemTeal)
                )

                featureCard(
                    item: .settings,
                    title: "Preferences & Exclusions",
                    description: "Configure automatic updates, exclude custom folders, and menu bar widget.",
                    icon: "gearshape.fill",
                    color: Color(nsColor: .systemGray)
                )
            }
        }
    }

    private func featureCard(item: SidebarItem, title: String, description: String, icon: String, color: Color) -> some View {
        Button {
            appState.selectedSidebarItem = item
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hardwareMetric(title: String, value: String, detail: String, fraction: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            if let fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .frame(height: 4)
            }

            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hardwareIcon: String {
        if specs.batteryLevel != nil {
            return "laptopcomputer"
        }
        let lower = specs.modelName.lowercased()
        if lower.contains("mini") {
            return "macmini"
        } else if lower.contains("studio") || lower.contains("pro") && !lower.contains("book") {
            return "macstudio"
        } else if lower.contains("imac") {
            return "desktopcomputer"
        }
        return "macbook.gen2"
    }

    private var uptimeFormatted: String {
        let hours = Int(specs.uptime / 3600)
        let days = hours / 24
        if days > 0 {
            return "\(days)d \(hours % 24)h"
        }
        return "\(hours)h"
    }
}
