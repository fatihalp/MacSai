import SwiftUI
import MacCleanKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Spacer()

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                fdaStep.tag(1)
                featuresStep.tag(2)
                readyStep.tag(3)
            }
            .tabViewStyle(.automatic)

            Spacer()

            HStack {
                if currentStep > 0 {
                    Button("Back") { withAnimation { currentStep -= 1 } }
                        .buttonStyle(.bordered)
                }

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? Color(nsColor: .systemBlue) : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentStep < 3 {
                    Button("Next") { withAnimation { currentStep += 1 } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                } else {
                    Button("Get Started") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                }
            }
            .padding(24)
        }

        .frame(width: 600, height: 620)
        .background(Color.white)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Welcome to \(MCConstants.appName)")
                .font(.system(size: 28, weight: .bold))

            Text("The open-source way to keep your Mac clean, fast, and secure.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
    }

    private var fdaStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Full Disk Access")
                .font(.system(size: 24, weight: .bold))

            Text("\(MCConstants.appName) needs Full Disk Access to scan Mail, Safari, and other protected areas. Without it, some features will be limited.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(alignment: .leading, spacing: 8) {
                step("1", String(localized: "Open System Settings"))
                step("2", String(localized: "Go to Privacy & Security → Full Disk Access"))
                step("3", "Click the + button and add \(MCConstants.appName)")
                step("4", "Restart \(MCConstants.appName)")
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("Open System Settings") {
                PermissionManager.shared.openFullDiskAccessSettings()
            }
            .buttonStyle(.bordered)
        }
    }

    private var featuresStep: some View {
        VStack(spacing: 20) {
            Text("What \(MCConstants.appName) Can Do")
                .font(.system(size: 24, weight: .bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                featureCard("trash.circle", String(localized: "System Junk"), String(localized: "Clean caches, logs, and temp files"))
                featureCard("shield.lefthalf.filled", String(localized: "Malware Scan"), String(localized: "Detect and remove threats"))
                featureCard("xmark.app", String(localized: "Uninstaller"), String(localized: "Completely remove apps"))
                featureCard("chart.pie", String(localized: "Space Lens"), String(localized: "Visualize disk usage"))
                featureCard("plus.square.on.square", String(localized: "Duplicates"), String(localized: "Find duplicate files"))
                featureCard("gauge.with.dots.needle.67percent", String(localized: "Performance"), String(localized: "Optimize your Mac"))
            }
            .frame(maxWidth: 450)
        }
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold))

            Text("Click Smart Scan to clean your Mac with one click, or explore individual modules in the sidebar.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color(nsColor: .systemBlue))
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
        }
    }

    private func featureCard(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(desc).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
