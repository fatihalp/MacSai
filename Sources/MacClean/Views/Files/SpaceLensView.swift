import SwiftUI
import MacCleanKit

struct SpaceLensView: View {
    @State private var controller = SpaceLensController()

    var body: some View {
        VStack(spacing: 0) {
            header
            breadcrumbBar
            content
        }
        .respondsToModuleShortcuts(
            onScan: controller.startScan,
            canScan: !controller.isScanning
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Space Lens")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("Visualize disk space usage")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                    if !controller.totalFormattedSize.isEmpty {
                        Text("·")
                            .foregroundStyle(.primary.opacity(0.3))
                        Text(controller.totalFormattedSize)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
            Spacer()
            if !controller.isScanning {
                Button("Scan") { controller.startScan() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.regular)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var breadcrumbBar: some View {
        Group {
            if controller.nav.breadcrumbs.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        Button { controller.nav.up(); controller.startScan() } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.plain).foregroundStyle(.primary.opacity(0.8))
                            .disabled(!controller.nav.canGoUp)
                            .help("Up one level")
                        Button { controller.nav.home(); controller.startScan() } label: { Image(systemName: "house") }
                            .buttonStyle(.plain).foregroundStyle(.primary.opacity(0.8))
                            .disabled(!controller.nav.canGoUp)
                            .help("Back to start")

                        ForEach(controller.nav.breadcrumbs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                controller.nav.navigate(to: url)
                                controller.startScan()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary.opacity(0.7))
                            .font(.system(size: 12))

                            if url != controller.nav.breadcrumbs.last {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if controller.isScanning {
            Spacer()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)
                Text("Scanning disk…")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.7))
                if controller.itemsScanned > 0 {
                    Text("\(controller.itemsScanned.formatted()) items scanned")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Button("Cancel") {
                    controller.cancelScan()
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            }
            Spacer()
        } else if !controller.treemapRects.isEmpty {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    treemapCanvas(containerSize: geo.size)
                    legend
                }
            }
        } else {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 44))
                    .foregroundStyle(.primary.opacity(0.4))
                Text("Click Scan to visualize disk usage")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.55))
            }
            Spacer()
        }
    }

    private func treemapCanvas(containerSize: CGSize) -> some View {
        let canvasWidth = max(containerSize.width - 40, 100)
        let canvasHeight = max(containerSize.height - 80, 200)
        let bounds = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        let rects = SquarifiedTreemap.layout(nodes: controller.treemapRects.map(\.node), in: bounds)

        return ZStack {
            ForEach(rects) { item in
                treemapCell(item)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func color(for category: FileTypeCategory) -> Color {
        switch category {
        case .folders: .blue
        case .documents: .orange
        case .images: .green
        case .video: .purple
        case .audio: .pink
        case .archives: .yellow
        case .code: .cyan
        case .diskImages: .teal
        case .applications: .indigo
        case .system: .gray
        case .other: Color(white: 0.6)
        }
    }

    private func treemapCell(_ item: TreemapRect) -> some View {
        let cat = item.node.fileTypeCategory
        let cellColor = color(for: cat)

        return RoundedRectangle(cornerRadius: 4)
            .fill(cellColor.opacity(0.7))
            .frame(width: max(item.rect.width - 2, 0), height: max(item.rect.height - 2, 0))
            .overlay {
                if item.rect.width > 60 && item.rect.height > 30 {
                    VStack(spacing: 2) {
                        Text(item.node.name)
                            .font(.system(size: max(9, min(13, item.rect.width / 10))))
                            .lineLimit(1)
                        Text(item.node.formattedSize)
                            .font(.system(size: max(8, min(10, item.rect.width / 12))))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.primary)
                    .padding(4)
                }
            }
            .position(x: item.rect.midX, y: item.rect.midY)
            .onTapGesture {
                if item.node.isDirectory {
                    controller.nav.drillInto(item.node.url)
                    controller.startScan()
                }
            }
            .help(item.node.name + " (" + item.node.fileTypeCategory.label + ")")
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FileTypeCategory.allCases, id: \.self) { cat in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: cat))
                            .frame(width: 10, height: 10)
                        Text(cat.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }
}
