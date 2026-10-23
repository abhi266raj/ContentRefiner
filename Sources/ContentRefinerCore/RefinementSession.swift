// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public struct RefinementTurn: Sendable, Equatable {
    public let directive: String
    public let result: RefinementResult
    public var selectedVariation: Int
    public init(directive: String, result: RefinementResult, selectedVariation: Int = 1) {
        self.directive = directive; self.result = result; self.selectedVariation = selectedVariation
    }
}

public struct RefinementSnapshot: Sendable, Equatable {
    public let originalContent: String
    public let latestContent: String
    public let instruction: String
    public let turns: [RefinementTurn]
}

/// Owns an immutable original and commits a turn only after complete, validated success.
public actor RefinementSession {
    private let original: String
    private let client: RefinementClient
    private var latest: String
    private var instruction: String
    private var turns: [RefinementTurn] = []
    private var isRunning = false

    public init(originalContent: String, instruction: String = "", client: RefinementClient) throws {
        guard !originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentRefinerError.invalidInput("Original content is required.")
        }
        self.original = originalContent; self.latest = originalContent; self.instruction = instruction; self.client = client
    }
    public var snapshot: RefinementSnapshot {
        .init(originalContent: original, latestContent: latest, instruction: instruction, turns: turns)
    }
    @discardableResult
    public func refine(_ directive: String, instructionOverride: String? = nil, variationCount: Int = 1,
                       contentKind: String = "auto", correctionFocus: [String] = [], knownIssues: [String] = [],
                       onEvent: @escaping @Sendable (RefinementEvent) async -> Void = { _ in }) async throws -> RefinementResult {
        guard !isRunning else { throw ContentRefinerError.busy }
        isRunning = true
        defer { isRunning = false }
        let active = instructionOverride ?? instruction
        let requested = directive.trimmingCharacters(in: .whitespacesAndNewlines)
        let effective = requested.isEmpty && !turns.isEmpty ? active : requested
        let input = ContentRefinementInput(originalContent: original, latestContent: latest, userInstruction: effective,
            instruction: active, variationCount: variationCount, contentKind: contentKind, correctionFocus: correctionFocus, knownIssues: knownIssues)
        let result = try await client.refine(input, onEvent: onEvent)
        try Task.checkCancellation()
        guard let first = result.output.variations.first(where: { $0.index == 1 }) else {
            throw ContentRefinerError.invalidOutput("Variation 1 is missing.")
        }
        latest = first.content
        instruction = result.output.instruction
        turns.append(.init(directive: effective, result: result))
        return result
    }
    public func selectVariation(_ index: Int) throws {
        guard !isRunning else { throw ContentRefinerError.busy }
        guard let last = turns.last, let variation = last.result.output.variations.first(where: { $0.index == index }) else {
            throw ContentRefinerError.invalidInput("Select an available variation from the latest turn.")
        }
        latest = variation.content
        turns[turns.count - 1].selectedVariation = index
    }
}
