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
    public init(timeoutSeconds: Double = 90, fallbackEnabled: Bool = true) {
        self.timeoutSeconds = timeoutSeconds; self.fallbackEnabled = fallbackEnabled
    }
}

public struct RefinementClient: Sendable {
    private let backends: [any RefinementBackend]
    public let configuration: RefinementConfiguration
    public init(backends: [any RefinementBackend], configuration: RefinementConfiguration = .init()) {
        self.backends = backends; self.configuration = configuration
    }
    public func refine(_ input: ContentRefinementInput,
                       onEvent: @escaping @Sendable (RefinementEvent) async -> Void = { _ in }) async throws -> RefinementResult {
        try input.validate()
        guard configuration.timeoutSeconds.isFinite, (0.01...3600).contains(configuration.timeoutSeconds) else {
            throw ContentRefinerError.invalidInput("Timeout must be between 0.01 and 3600 seconds.")
        }
        guard !backends.isEmpty, Set(backends.map(\.id)).count == backends.count else {
            throw ContentRefinerError.invalidInput("Choose at least one provider with unique identifiers.")
        }
        var attempts: [RefinementAttempt] = []
        for backend in configuration.fallbackEnabled ? backends : Array(backends.prefix(1)) {
            try Task.checkCancellation()
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
                attempts.append(.init(providerID: backend.id, succeeded: true, message: "Completed", duration: Date().timeIntervalSince(start)))
                await onEvent(.completed(backend.id))
                return .init(output: output, providerID: backend.id, rawResponse: raw, attempts: attempts)
            } catch {
                if Task.isCancelled || error is CancellationError { throw CancellationError() }
                let attempt = RefinementAttempt(providerID: backend.id, succeeded: false, message: error.localizedDescription, duration: Date().timeIntervalSince(start))
                attempts.append(attempt)
                await onEvent(.failed(attempt))
            }
        }
        throw ContentRefinerError.allProvidersFailed(attempts)
    }
}
