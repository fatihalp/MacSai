import SwiftUI

private enum ModuleIsSelectedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var moduleIsSelected: Bool {
        get { self[ModuleIsSelectedKey.self] }
        set { self[ModuleIsSelectedKey.self] = newValue }
    }
}

struct RespondsToModuleShortcuts: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(\.moduleIsSelected) private var isSelected
    let onScan: () -> Void
    let onClean: (() -> Void)?
    let canScan: Bool
    let canClean: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.scanShortcutNonce) { _, _ in
                guard isSelected, canScan else { return }
                onScan()
            }
            .onChange(of: appState.cleanShortcutNonce) { _, _ in
                guard isSelected, canClean, let onClean else { return }
                onClean()
            }
    }
}

extension View {
    func respondsToModuleShortcuts(
        onScan: @escaping () -> Void,
        onClean: (() -> Void)? = nil,
        canScan: Bool = true,
        canClean: Bool = false
    ) -> some View {
        modifier(RespondsToModuleShortcuts(
            onScan: onScan,
            onClean: onClean,
            canScan: canScan,
            canClean: canClean
        ))
    }
}

enum DuplicatesShortcutOwnership {
    enum CleanOwner: Equatable {
        case none
        case container
    }

    static let outerCanClean = false

    static func cleanOwner(showingContainerResults: Bool) -> CleanOwner {
        showingContainerResults ? .container : .none
    }
}
