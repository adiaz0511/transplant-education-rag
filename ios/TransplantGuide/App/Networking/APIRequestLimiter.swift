import Foundation

actor APIRequestLimiter {
    struct Lease: Sendable {
        let id: UUID
        let estimatedTokens: Int
        let reservedAt: Date
    }

    enum Endpoint: Sendable {
        case ask
        case lesson
        case quiz

        var baseTokenOverhead: Int {
            switch self {
            case .ask:
                return 24_000
            case .lesson:
                return 48_000
            case .quiz:
                return 28_000
            }
        }

        var outputReserve: Int {
            switch self {
            case .ask:
                return 2_000
            case .lesson:
                return 5_000
            case .quiz:
                return 3_000
            }
        }
    }

    static let shared = APIRequestLimiter()

    private let maxConcurrentRequests = 2
    private let maxEstimatedTokensPerMinute = 115_000
    private let rollingWindow: TimeInterval = 60
    private let cooldownDuration: TimeInterval = 20

    private var activeLeases: Set<UUID> = []
    private var recentReservations: [Lease] = []
    private var cooldownUntil: Date?

    func acquire(endpoint: Endpoint, body: [String: String]) async throws -> Lease {
        let estimatedTokens = min(
            estimateTokens(for: endpoint, body: body),
            maxEstimatedTokensPerMinute
        )

        while true {
            pruneExpiredReservations()

            if let waitDuration = waitDurationBeforeNextLease(for: estimatedTokens) {
                let sleepDuration = UInt64(max(waitDuration, 0.25) * 1_000_000_000)
                try await Task.sleep(nanoseconds: sleepDuration)
                continue
            }

            let lease = Lease(
                id: UUID(),
                estimatedTokens: estimatedTokens,
                reservedAt: Date()
            )
            activeLeases.insert(lease.id)
            recentReservations.append(lease)
            return lease
        }
    }

    func release(_ lease: Lease) {
        activeLeases.remove(lease.id)
    }

    func cancel(_ lease: Lease) {
        activeLeases.remove(lease.id)
        recentReservations.removeAll { $0.id == lease.id }
    }

    func registerRateLimitSignal() {
        let nextCooldown = Date().addingTimeInterval(cooldownDuration)

        if let cooldownUntil, cooldownUntil > nextCooldown {
            return
        }

        cooldownUntil = nextCooldown
    }

    private func waitDurationBeforeNextLease(for estimatedTokens: Int) -> TimeInterval? {
        if let cooldownUntil {
            let cooldownWait = cooldownUntil.timeIntervalSinceNow
            if cooldownWait > 0 {
                return cooldownWait
            }

            self.cooldownUntil = nil
        }

        if activeLeases.count >= maxConcurrentRequests {
            return 0.5
        }

        let reservedTokens = recentReservations.reduce(into: 0) { partialResult, lease in
            partialResult += lease.estimatedTokens
        }

        if reservedTokens + estimatedTokens <= maxEstimatedTokensPerMinute {
            return nil
        }

        guard let oldestReservation = recentReservations.first else {
            return 0.5
        }

        let nextAvailableDate = oldestReservation.reservedAt.addingTimeInterval(rollingWindow)
        return max(nextAvailableDate.timeIntervalSinceNow, 0.5)
    }

    private func pruneExpiredReservations() {
        let cutoffDate = Date().addingTimeInterval(-rollingWindow)
        recentReservations.removeAll { $0.reservedAt < cutoffDate }
    }

    private func estimateTokens(for endpoint: Endpoint, body: [String: String]) -> Int {
        let promptCharacters = body.values.reduce(into: 0) { partialResult, value in
            partialResult += value.count
        }
        let promptTokens = max(Int(ceil(Double(promptCharacters) / 4.0)), 1_000)

        return endpoint.baseTokenOverhead + endpoint.outputReserve + promptTokens
    }
}
