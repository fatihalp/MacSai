import SwiftUI
import MacCleanKit

struct ShredderView: View {
    @State private var controller = ShredderController()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shredder")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Securely erase files beyond recovery")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                Spacer()
            }
            .padding(20)

            Spacer()

            if let result = controller.result {
                VStack(spacing: 16) {
                    Image(systemName: result.errors.isEmpty
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(result.errors.isEmpty ? Color.primary : Color.orange)
                    Text("\(result.erasedCount) files erased")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(FileSizeFormatter.format(result.totalSize))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary.opacity(0.7))

                    if let firstError = result.errors.first?.1 {
                        Text(firstError)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .textSelection(.enabled)

                        if result.errors.count > 1 {
                            Text("And \(result.errors.count - 1) more error\(result.errors.count == 2 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                    }

                    Button("Done") {
                        controller.result = nil
                        controller.filesToShred = []
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }
            } else if controller.isProcessing {
                ProgressView("Shredding files...")
                    .foregroundStyle(.primary)
                    .tint(.primary)
            } else if controller.filesToShred.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "scissors")
                        .font(.system(size: 50))
                        .foregroundStyle(.primary.opacity(0.5))

                    Text("Drop files here to shred them")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.6))

                    Button("Select Files") {
                        controller.selectFiles()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(nsColor: .systemBlue))
                    .controlSize(.large)

                    Picker("Mode", selection: $controller.eraseMode) {
                        Text("Move to Trash").tag(SecureEraser.EraseMode.standard)
                        Text("Permanent Delete").tag(SecureEraser.EraseMode.permanent)
                        Text("Secure Erase").tag(SecureEraser.EraseMode.secure)
                    }
                    .pickerStyle(.segmented)

                    .labelsHidden()
                    .frame(width: 360)
                    .padding(.top, 8)
                }
            } else {
                VStack(spacing: 16) {
                    Text("\(controller.filesToShred.count) files selected")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    List(controller.filesToShred, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc")
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                controller.filesToShred.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.inset)
                    .frame(maxHeight: 200)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)

                    Button("Shred") {
                        controller.shred()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
    }
}
