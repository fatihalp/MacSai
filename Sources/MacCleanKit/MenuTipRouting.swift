import Foundation

public enum MenuTipRouting {
    public static func moduleID(forTipID id: String) -> String? {
        switch id {
        case "trash_large": "trash-bins"
        case "caches_large": "system-junk"
        default: nil
        }
    }
}
