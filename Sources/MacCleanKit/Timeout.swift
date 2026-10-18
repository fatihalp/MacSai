import Foundation
import os

public struct TimeoutError: Error, Equatable {
    public init() {}
}

public func withTimeout<T: Sendable>(
    _ duration: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = TimeoutRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            race.start(
                continuation,
                work: Task {
                    do { race.finish(.success(try await operation())) } catch { race.finish(.failure(error)) }
                },
                clock: Task {
                    do {
                        try await Task.sleep(for: duration)
                        race.finish(.failure(TimeoutError()))
                    } catch {}
                }
            )
        }
    } onCancel: {
        race.finish(.failure(CancellationError()))
    }
}

private final class TimeoutRace<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, Error>?
        var tasks: [Task<Void, Never>] = []
        var outcome: Result<T, Error>?
    }

    private let state = OSAllocatedUnfairLock<State>(uncheckedState: State())

    func start(_ continuation: CheckedContinuation<T, Error>, work: Task<Void, Never>, clock: Task<Void, Never>) {
        let early: Result<T, Error>? = state.withLockUnchecked { state in
            if let outcome = state.outcome { return outcome }
            state.continuation = continuation
            state.tasks = [work, clock]
            return nil
        }
        if let early {
            work.cancel()
            clock.cancel()
            continuation.resume(with: early)
        }
    }

    func finish(_ outcome: Result<T, Error>) {
        let (continuation, tasks): (CheckedContinuation<T, Error>?, [Task<Void, Never>]) =
            state.withLockUnchecked { state in
                guard state.outcome == nil else { return (nil, []) }
                state.outcome = outcome
                defer { state.continuation = nil; state.tasks = [] }
                return (state.continuation, state.tasks)
            }
        tasks.forEach { $0.cancel() }
        continuation?.resume(with: outcome)
    }
}
