import Foundation

public struct CleanSummary: Sendable, Equatable, Identifiable {

    public let id = UUID()

    public let selectedCount: Int

    public let removedCount: Int

    public let freedBytes: UInt64

    public let errorMessages: [String]

    public var errorCount: Int { errorMessages.count }

    public static func == (lhs: CleanSummary, rhs: CleanSummary) -> Bool {
        lhs.selectedCount == rhs.selectedCount
            && lhs.removedCount == rhs.removedCount
            && lhs.freedBytes == rhs.freedBytes
            && lhs.errorMessages == rhs.errorMessages
    }

    public var firstErrorMessage: String? { errorMessages.first }

    public var topErrorGroups: [ErrorGroup] {
        ErrorGroup.top(in: errorMessages, k: 3)
    }

    public init(
        selectedCount: Int,
        removedCount: Int,
        freedBytes: UInt64,
        errorMessages: [String]
    ) {
        self.selectedCount = selectedCount
        self.removedCount = removedCount
        self.freedBytes = freedBytes
        self.errorMessages = errorMessages
    }

    public struct ErrorGroup: Sendable, Equatable, Hashable {
        public let message: String
        public let count: Int

        public init(message: String, count: Int) {
            self.message = message
            self.count = count
        }

        public static func top(in messages: [String], k: Int) -> [ErrorGroup] {
            guard k > 0, !messages.isEmpty else { return [] }
            let grouped = Dictionary(grouping: messages, by: { $0 })
                .map { ErrorGroup(message: $0.key, count: $0.value.count) }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.message < $1.message
                }
            return Array(grouped.prefix(k))
        }
    }
}
