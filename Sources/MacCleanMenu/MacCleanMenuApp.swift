import SwiftUI
import AppKit
import MacCleanKit

@main
struct MacCleanMenuApp: App {
    init() {
        if let myBundleID = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let running = NSWorkspace.shared.runningApplications
            let me = running.first { $0.processIdentifier == myPID }
            let siblings = running.compactMap { app -> MenuBarInstance? in
                guard app.bundleIdentifier == myBundleID,
                      app.processIdentifier != myPID else { return nil }
                return MenuBarInstance(pid: app.processIdentifier, launchDate: app.launchDate)
            }

            if MenuBarInstancePolicy.shouldExitAsDuplicate(
                selfPID: myPID,
                selfLaunchDate: me?.launchDate,
                siblings: siblings
            ) {
                exit(0)
            }
        }
    }

    @NSApplicationDelegateAdaptor(MenuAppDelegate.self) private var appDelegate
    @State private var model = MenuStatsModel.shared
    @AppStorage(Localization.defaultsKey, store: SharedAppState.defaults) private var appLanguage = "en"
    @AppStorage(MenuBarMetric.defaultsKey, store: SharedAppState.defaults) private var menuBarMetricRaw = MenuBarMetric.diskFree.rawValue

    private static let labelIcon: NSImage = {
        let img = NSImage(systemSymbolName: "sparkles",
                          accessibilityDescription: "Mac Sai")!
        img.isTemplate = true
        return img
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                stats: model.stats,
                networkSpeed: model.networkSpeed,
                devices: model.devices,
                protection: model.protection,
                tips: model.tips,
                onDismissTip: { model.dismissTip(id: $0) }
            )
            .environment(\.locale, Localization.locale(for: appLanguage))
            .id(appLanguage)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: Self.labelIcon)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                if let stats = model.stats,
                   let value = MenuBarMetric.resolve(menuBarMetricRaw).formattedValue(
                       diskFree: stats.diskFree,
                       gpuUsage: stats.gpuUsage,
                       memoryUsage: stats.memoryTotal > 0
                           ? Double(stats.memoryUsed) / Double(stats.memoryTotal)
                           : 0,
                       batteryTemperature: stats.batteryTemperature
                   ) {
                    Text(value)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuPalette {
    static let bgTop = Color(nsColor: .windowBackgroundColor)
    static let bgBottom = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let teal = Color.accentColor
    static let yellow = Color.orange
    static let green = Color.accentColor
    static let red = Color.red
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static func barColor(_ v: Double) -> Color {
        if v > 0.85 { return .red }
        if v > 0.65 { return yellow }
        return teal
    }
}

struct MenuContentView: View {
    let stats: SystemStatsCollector.SystemStats?
    let networkSpeed: NetworkSpeedMonitor.NetworkSpeed?
    let devices: ConnectedDevices?
    let protection: SharedAppState.ProtectionStatus?
    let tips: [TipsEngine.Tip]
    let onDismissTip: (String) -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                if let stats {
                    statGrid(stats)
                    networkCard(stats)
                    if !tips.isEmpty { recommendationsCard }
                    if let p = protection { protectionCard(p) }
                    if let d = devices, d.hasAny { devicesCard(d) }
                } else {
                    ProgressView().controlSize(.small).tint(.white)
                        .frame(height: 100)
                }
                footer
            }
            .padding(14)
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: VacuumAsset.image)
                .resizable().interpolation(.high)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(MCConstants.appName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MenuPalette.textPrimary)
                Text("Live system stats")
                    .font(.system(size: 10))
                    .foregroundStyle(MenuPalette.textSecondary)
            }
            Spacer()
        }
    }

    private func statGrid(_ s: SystemStatsCollector.SystemStats) -> some View {
        let diskUsed = s.diskTotal > 0 ? Double(s.diskTotal - s.diskFree) / Double(s.diskTotal) : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ringCard(icon: "cpu", label: "CPU",
                     value: s.cpuUsage, center: "\(Int((s.cpuUsage*100).rounded()))%",
                     sub: nil)
            ringCard(icon: "memorychip", label: String(localized: "Memory"),
                     value: s.memoryPressure, center: "\(Int((s.memoryPressure*100).rounded()))%",
                     sub: FileSizeFormatter.format(s.memoryUsed))
            ringCard(icon: "internaldrive", label: String(localized: "Disk"),
                     value: diskUsed, center: "\(Int((diskUsed*100).rounded()))%",
                     sub: "\(FileSizeFormatter.format(s.diskFree)) free")
            if let level = s.batteryLevel {
                ringCard(icon: s.batteryIsCharging ? "battery.100.bolt" : "battery.75",
                         label: s.batteryIsCharging ? String(localized: "Charging") : String(localized: "Battery"),
                         value: level, center: "\(Int((level*100).rounded()))%",
                         sub: nil, forceColor: level > 0.2 ? MenuPalette.teal : Color(red:0.98,green:0.42,blue:0.45))
            } else {
                uptimeCard(s)
            }
        }
    }

    private func ringCard(icon: String, label: String, value: Double, center: String, sub: String?, forceColor: Color? = nil) -> some View {
        let color = forceColor ?? MenuPalette.barColor(value)
        return VStack(spacing: 12) {
            statHeader(icon: icon, label: label, tint: color)
            RingGauge(value: value, color: color, center: center)
                .frame(width: 58, height: 58)

            Text(sub ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(MenuPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(16)
        .glassCard()
    }

    private func uptimeCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        VStack(spacing: 12) {
            statHeader(icon: "clock", label: String(localized: "Uptime"), tint: MenuPalette.teal)
            Text(formatUptime(s.uptime))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(height: 58)
            Text(" ").font(.system(size: 10, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(16)
        .glassCard()
    }

    private func statHeader(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuPalette.textPrimary)
        }
    }

    private func networkCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        HStack(spacing: 0) {
            if let net = networkSpeed {
                netCell(icon: "arrow.down", color: MenuPalette.teal, value: net.formattedIn)
                divider
                netCell(icon: "arrow.up", color: MenuPalette.yellow, value: net.formattedOut)
                divider
            }
            netCell(icon: "clock", color: MenuPalette.textSecondary, value: formatUptime(s.uptime))
            if s.swapUsed > 0 {
                divider
                netCell(icon: "arrow.triangle.swap", color: MenuPalette.textSecondary, value: FileSizeFormatter.format(s.swapUsed))
            }
        }
        .padding(.vertical, 9)
        .glassCard()
    }

    private func netCell(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 18)
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader(icon: "sparkles", title: String(localized: "Recommendations"), tint: MenuPalette.yellow)
            ForEach(tips.prefix(3)) { tip in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tip.symbol).font(.system(size: 12)).foregroundStyle(MenuPalette.teal).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                            Text(tip.body).font(.system(size: 10)).foregroundStyle(MenuPalette.textSecondary).lineLimit(2)
                        }
                        Spacer(minLength: 2)
                        Button { onDismissTip(tip.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                .foregroundStyle(MenuPalette.textSecondary).padding(4)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }.buttonStyle(.plain).help(String(localized: "Dismiss for 30 days"))
                    }
                    Button { TipAction.open(moduleID: MenuTipRouting.moduleID(forTipID: tip.id)) } label: {
                        Text(tipCTA(tip)).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(red:0.16,green:0.10,blue:0.30))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(MenuPalette.yellow, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(11)
        .glassCard()
    }

    private func tipCTA(_ tip: TipsEngine.Tip) -> String {
        switch tip.id {
        case "trash_large": return String(localized: "Empty Trash")
        case "caches_large": return String(localized: "Free Up Space")
        default: return "Open \(MCConstants.appName)"
        }
    }

    private func protectionCard(_ p: SharedAppState.ProtectionStatus) -> some View {
        let tint = p.threatsFound > 0 ? Color(red:0.98,green:0.42,blue:0.45) : (p.isStale ? MenuPalette.yellow : MenuPalette.teal)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: p.threatsFound > 0 ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(p.threatsFound > 0 ? "\(p.threatsFound) threat\(p.threatsFound == 1 ? "" : "s") found" : String(localized: "Protected"))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text("Scanned \(relativeTime(p.lastScanDate)) · \(p.localizedScanDepth)")
                    .font(.system(size: 10)).foregroundStyle(MenuPalette.textSecondary)
            }
            Spacer()
        }
        .padding(11).glassCard()
    }

    private func devicesCard(_ d: ConnectedDevices) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "externaldrive.connected.to.line.below", title: String(localized: "Connected"), tint: MenuPalette.teal)
            ForEach(d.externalVolumes) { v in
                HStack(spacing: 7) {
                    Image(systemName: "externaldrive.fill").font(.system(size: 10)).foregroundStyle(MenuPalette.teal.opacity(0.8))
                    Text(v.name).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(FileSizeFormatter.format(v.freeBytes)) free").font(.system(size: 10, design: .monospaced)).foregroundStyle(MenuPalette.textSecondary)
                }
            }
            if d.externalDisplays > 0 {
                HStack(spacing: 7) {
                    Image(systemName: "display").font(.system(size: 10)).foregroundStyle(MenuPalette.teal.opacity(0.8))
                    Text("\(d.externalDisplays) external display\(d.externalDisplays == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .padding(11).glassCard()
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                MenuBarKeepAlive.setUserQuit(true, defaults: SharedAppState.defaults)
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 32)
                    .background(MenuPalette.red, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain).help(String(localized: "Quit Monitor"))

            Button { TipAction.open() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").font(.system(size: 11, weight: .bold))
                    Text("Open \(MCConstants.appName)").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(MenuPalette.green, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain)
        }
    }

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            Spacer()
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = (Int(seconds) % 3600) / 60
        if h > 24 { return "\(h/24)d \(h%24)h" }
        return "\(h)h \(m)m"
    }

    private func relativeTime(_ date: Date) -> String {
        let i = Date().timeIntervalSince(date)
        if i < 60 { return String(localized: "just now") }
        if i < 3600 { return "\(Int(i/60)) min ago" }
        if i < 86400 { return "\(Int(i/3600)) hr ago" }
        return "\(Int(i/86400)) day\(Int(i/86400) == 1 ? "" : "s") ago"
    }
}

struct RingGauge: View {
    let value: Double
    let color: Color
    let center: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(center).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(MenuPalette.card.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.ultraThinMaterial.opacity(0.30),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}
