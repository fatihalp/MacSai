import Foundation

public enum SupportPrompt {
    public static let minFreedBytes: UInt64 = 1_000_000_000
    public static let minCleanCount = 2
    public static let cooldown: TimeInterval = 60 * 24 * 60 * 60

    static let cleanCountKey = "supportPrompt.cleanCount"
    static let lastShownKey = "supportPrompt.lastShown"
    static let optedOutKey = "supportPrompt.optedOut"

    public struct State: Equatable, Sendable {

        public var cleanCount: Int
        public var lastShown: Date?
        public var optedOut: Bool

        public init(cleanCount: Int, lastShown: Date?, optedOut: Bool) {
            self.cleanCount = cleanCount
            self.lastShown = lastShown
            self.optedOut = optedOut
        }
    }

    public static func shouldShow(state: State, freedBytes: UInt64, now: Date) -> Bool {
        guard !state.optedOut,
              freedBytes >= minFreedBytes,
              state.cleanCount >= minCleanCount else { return false }
        guard let lastShown = state.lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= cooldown
    }

    public static func state(defaults: UserDefaults = .standard) -> State {
        State(
            cleanCount: defaults.integer(forKey: cleanCountKey),
            lastShown: defaults.object(forKey: lastShownKey) as? Date,
            optedOut: defaults.bool(forKey: optedOutKey)
        )
    }

    public static func registerClean(
        freedBytes: UInt64,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        var current = state(defaults: defaults)
        current.cleanCount += 1
        defaults.set(current.cleanCount, forKey: cleanCountKey)
        guard shouldShow(state: current, freedBytes: freedBytes, now: now) else { return false }
        defaults.set(now, forKey: lastShownKey)
        return true
    }

    public static func registerCompletion(
        _ summary: CleanSummary,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard summary.removedCount > 0 else { return false }
        return registerClean(freedBytes: summary.freedBytes, now: now, defaults: defaults)
    }

    public static func optOut(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: optedOutKey)
    }
}

@MainActor
public final class SupportAskLedger {
    public static let shared = SupportAskLedger()

    private let defaults: UserDefaults
    private var decisions: [UUID: Bool] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func shouldAsk(for summary: CleanSummary, now: Date = Date()) -> Bool {
        if let decided = decisions[summary.id] { return decided }
        let decision = SupportPrompt.registerCompletion(summary, now: now, defaults: defaults)
        decisions[summary.id] = decision
        return decision
    }
}
