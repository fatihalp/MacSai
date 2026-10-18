import Foundation

public struct DiskUsage: Sendable, Equatable {
    public let total: UInt64
    public let free: UInt64

    public init(total: UInt64, free: UInt64) {
        self.total = total
        self.free = min(free, total)
    }

    public static func fromStatfs(blocks: UInt64, availableBlocks: UInt64, blockSize: UInt64) -> DiskUsage {
        DiskUsage(total: blocks &* blockSize, free: availableBlocks &* blockSize)
    }

    public var used: UInt64 { total >= free ? total - free : 0 }

    public var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }
}
