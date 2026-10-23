// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public protocol RefinementBackend: Sendable {
    var id: String { get }
    /// Implementations must cooperate with cancellation so deadlines can release resources.
    func refine(_ input: ContentRefinementInput) async throws -> String
}

public enum RefinementEvent: Sendable {
    case started(String), failed(RefinementAttempt), completed(String)
}

public struct RefinementConfiguration: Sendable, Equatable {
    public var timeoutSeconds: Double
    public var fallbackEnabled: Bool
    /// How long the newest started provider may run without a result before
    /// the next provider joins. Zero joins every provider immediately.
    public var hedgeDelaySeconds: Double
    public init(timeoutSeconds: Double = 90, fallbackEnabled: Bool = true, hedgeDelaySeconds: Double = 10) {
        self.timeoutSeconds = timeoutSeconds; self.fallbackEnabled = fallbackEnabled; self.hedgeDelaySeconds = hedgeDelaySeconds
    }
}

/// Starts only the first (selected) provider. A fallback joins only when every
/// running provider has failed or the newest provider stalls past the hedge
/// delay, so a healthy primary never triggers duplicate provider calls. The
/// first complete, validated success wins; providers still running are then
/// cancelled, never awaited. The per-provider timeout bounds the case where no
/// provider responds. Cancellation cancels every in-flight attempt and starts
/// nothing new.
public struct RefinementClient: Sendable {
    private let backends: [any RefinementBackend]
    public let configuration: RefinementConfiguration
    public init(backends: [any RefinementBackend], configuration: RefinementConfiguration = .init()) {
        self.backends = backends; self.configuration = configuration
    }

    private enum Outcome: Sendable {
        case success(index: Int, providerID: String, raw: String, output: ContentRefinementOutput, duration: TimeInterval)
        case failure(index: Int, attempt: RefinementAttempt, cancelled: Bool)
        case hedgeTick(generation: Int)
    }

    public func refine(_ input: ContentRefinementInput,
                       onEvent: @escaping @Sendable (RefinementEvent) async -> Void = { _ in }) async throws -> RefinementResult {
        try input.validate()
        guard configuration.timeoutSeconds.isFinite, (0.01...3600).contains(configuration.timeoutSeconds) else {
            throw ContentRefinerError.invalidInput("Timeout must be between 0.01 and 3600 seconds.")
        }
        guard configuration.hedgeDelaySeconds.isFinite, configuration.hedgeDelaySeconds >= 0 else {
            throw ContentRefinerError.invalidInput("Hedge delay must be zero or more seconds.")
        }
        guard !backends.isEmpty, Set(backends.map(\.id)).count == backends.count else {
            throw ContentRefinerError.invalidInput("Choose at least one provider with unique identifiers.")
        }
        let active = configuration.fallbackEnabled ? backends : Array(backends.prefix(1))
        return try await withThrowingTaskGroup(of: Outcome.self) { group in
            var attempts: [Int: RefinementAttempt] = [:]
            var winner: (index: Int, providerID: String, raw: String, output: ContentRefinementOutput)?
            var nextIndex = 0
            var running = 0
            var generation = 0
            func startNext() {
                guard nextIndex < active.count, winner == nil else { return }
                let index = nextIndex; nextIndex += 1; running += 1; generation += 1
                let backend = active[index]
                group.addTask { await self.attempt(index: index, backend: backend, input: input, onEvent: onEvent) }
                if nextIndex < active.count {
                    let tickGeneration = generation
                    let delay = configuration.hedgeDelaySeconds
                    group.addTask {
                        try? await Task.sleep(for: .seconds(delay))
                        return .hedgeTick(generation: tickGeneration)
                    }
                }
            }
            startNext()
            while let outcome = try? await group.next() {
                switch outcome {
                case .success(let index, let providerID, let raw, let output, let duration):
                    running -= 1
                    attempts[index] = .init(providerID: providerID, succeeded: true, message: "Completed", duration: duration)
                    if winner == nil {
                        winner = (index, providerID, raw, output)
                        await onEvent(.completed(providerID))
                        group.cancelAll()
                    }
                case .failure(let index, var attempt, let cancelled):
                    running -= 1
                    if cancelled, let winner {
                        attempt = .init(providerID: attempt.providerID, succeeded: false,
                                        message: "Superseded by \(winner.providerID)", duration: attempt.duration)
                    }
                    attempts[index] = attempt
                    if winner == nil {
                        await onEvent(.failed(attempt))
                        if running == 0 { startNext() }
                    }
                case .hedgeTick(let tickGeneration):
                    // Only the newest provider's stall timer may escalate.
                    if winner == nil, tickGeneration == generation, running > 0 { startNext() }
                }
                // Nothing left to run or start: drop pending stall timers so
                // the group drains now instead of after the hedge delay.
                if winner == nil, running == 0, nextIndex == active.count { group.cancelAll() }
            }
            if Task.isCancelled { throw CancellationError() }
            let ordered = attempts.sorted { $0.key < $1.key }.map(\.value)
            guard let winner else { throw ContentRefinerError.allProvidersFailed(ordered) }
            return .init(output: winner.output, providerID: winner.providerID, rawResponse: winner.raw, attempts: ordered)
        }
    }

    /// One provider attempt with its own timeout race. Never throws: the outcome
    /// (including cancellation and malformed output) is reported as a value so
    /// the group can rank every provider by completion order.
    private func attempt(index: Int, backend: any RefinementBackend, input: ContentRefinementInput,
                         onEvent: @escaping @Sendable (RefinementEvent) async -> Void) async -> Outcome {
        await onEvent(.started(backend.id))
        let start = Date()
        do {
            let raw = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { try await backend.refine(input) }
                group.addTask {
                    try await Task.sleep(for: .seconds(configuration.timeoutSeconds))
                    throw ContentRefinerError.timedOut(backend.id)
                }
                defer { group.cancelAll() }
                guard let value = try await group.next() else { throw CancellationError() }
                return value
            }
            try Task.checkCancellation()
            let output: ContentRefinementOutput
            do { output = try JSONDecoder().decode(ContentRefinementOutput.self, from: Data(raw.utf8)) }
            catch { throw ContentRefinerError.invalidOutput("The provider returned malformed refinement output.") }
            try output.validate(for: input)
            return .success(index: index, providerID: backend.id, raw: raw, output: output,
                            duration: Date().timeIntervalSince(start))
        } catch {
            let cancelled = error is CancellationError
            let attempt = RefinementAttempt(providerID: backend.id, succeeded: false,
                                            message: error.localizedDescription,
                                            duration: Date().timeIntervalSince(start))
            return .failure(index: index, attempt: attempt, cancelled: cancelled)
        }
    }
}
