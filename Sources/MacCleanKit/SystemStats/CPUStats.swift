import Foundation

public struct CPUTicks: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public static let statesPerCPU = 4
    private static let userIndex = 0
    private static let systemIndex = 1
    private static let idleIndex = 2
    private static let niceIndex = 3

    public static func summed(rawLoadInfo: [Int32], cpuCount: Int) -> CPUTicks {
        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0
        for i in 0..<cpuCount {
            let base = statesPerCPU * i
            guard base + niceIndex < rawLoadInfo.count else { break }

            user   += UInt64(UInt32(bitPattern: rawLoadInfo[base + userIndex]))
            system += UInt64(UInt32(bitPattern: rawLoadInfo[base + systemIndex]))
            idle   += UInt64(UInt32(bitPattern: rawLoadInfo[base + idleIndex]))
            nice   += UInt64(UInt32(bitPattern: rawLoadInfo[base + niceIndex]))
        }
        return CPUTicks(user: user, system: system, idle: idle, nice: nice)
    }
}

public struct CPUUsage: Sendable, Equatable {
    public let userFraction: Double
    public let systemFraction: Double
    public let idleFraction: Double
    public let niceFraction: Double

    public var totalActiveFraction: Double {
        userFraction + systemFraction + niceFraction
    }

    public init?(previous: CPUTicks, current: CPUTicks) {
        guard current.user >= previous.user, current.system >= previous.system,
              current.idle >= previous.idle, current.nice >= previous.nice else { return nil }
        let userDiff   = current.user   &- previous.user
        let systemDiff = current.system &- previous.system
        let idleDiff   = current.idle   &- previous.idle
        let niceDiff   = current.nice   &- previous.nice
        let total = userDiff &+ systemDiff &+ idleDiff &+ niceDiff
        guard total > 0 else { return nil }
        let t = Double(total)
        self.userFraction   = Double(userDiff)   / t
        self.systemFraction = Double(systemDiff) / t
        self.idleFraction   = Double(idleDiff)   / t
        self.niceFraction   = Double(niceDiff)   / t
    }

    public init(userFraction: Double, systemFraction: Double,
                idleFraction: Double, niceFraction: Double) {
        self.userFraction = userFraction
        self.systemFraction = systemFraction
        self.idleFraction = idleFraction
        self.niceFraction = niceFraction
    }
}
