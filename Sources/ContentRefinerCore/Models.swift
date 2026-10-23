// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public struct ContentRefinementInput: Codable, Sendable, Equatable {
    public var originalContent: String
    public var latestContent: String
    public var userInstruction: String
    public var instruction: String
    public var variationCount: Int
    public var contentKind: String
    public var correctionFocus: [String]
    public var knownIssues: [String]

    public init(originalContent: String, latestContent: String? = nil, userInstruction: String,
                instruction: String = "", variationCount: Int = 1, contentKind: String = "auto",
                correctionFocus: [String] = [], knownIssues: [String] = []) {
        self.originalContent = originalContent
        self.latestContent = latestContent ?? originalContent
        self.userInstruction = userInstruction
        self.instruction = instruction
        self.variationCount = variationCount
        self.contentKind = contentKind
        self.correctionFocus = correctionFocus
        self.knownIssues = knownIssues
    }

    public func validate() throws {
        guard !originalContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !latestContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !userInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentRefinerError.invalidInput("Original content, latest content and a refinement instruction are required.")
        }
        guard (1...5).contains(variationCount) else { throw ContentRefinerError.invalidInput("Request between 1 and 5 variations.") }
    }
}

public struct RefinementVariation: Codable, Sendable, Equatable, Identifiable {
    public let index: Int
    public let content: String
    public let notes: String
    public var id: Int { index }
    public init(index: Int, content: String, notes: String = "") { self.index = index; self.content = content; self.notes = notes }
}

public struct RefinementIssue: Codable, Sendable, Equatable {
    public let category: String
    public let description: String
    public let correction: String
    public init(category: String, description: String, correction: String) {
        self.category = category; self.description = description; self.correction = correction
    }
}

public struct ContentRefinementOutput: Codable, Sendable, Equatable {
    public let variations: [RefinementVariation]
    public let detectedIssues: [RefinementIssue]
    public let instruction: String
    public init(variations: [RefinementVariation], detectedIssues: [RefinementIssue] = [], instruction: String) {
        self.variations = variations; self.detectedIssues = detectedIssues; self.instruction = instruction
    }
    public func validate(for input: ContentRefinementInput) throws {
        guard variations.count == input.variationCount, Set(variations.map(\.index)) == Set(1...input.variationCount),
              variations.allSatisfy({ !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentRefinerError.invalidOutput("The provider must return the requested complete variations and consolidated instructions.")
        }
    }
}

public struct RefinementAttempt: Codable, Sendable, Equatable, Identifiable {
    public let providerID: String
    public let succeeded: Bool
    public let message: String
    public let duration: TimeInterval
    public var id: String { providerID }
    public init(providerID: String, succeeded: Bool, message: String, duration: TimeInterval) {
        self.providerID = providerID; self.succeeded = succeeded; self.message = message; self.duration = duration
    }
}

public struct RefinementResult: Sendable, Equatable {
    public let output: ContentRefinementOutput
    public let providerID: String
    public let rawResponse: String
    public let attempts: [RefinementAttempt]
    public init(output: ContentRefinementOutput, providerID: String, rawResponse: String, attempts: [RefinementAttempt]) {
        self.output = output; self.providerID = providerID; self.rawResponse = rawResponse; self.attempts = attempts
    }
}

public enum ContentRefinerError: LocalizedError, Sendable {
    case invalidInput(String), invalidOutput(String), unavailable(String), timedOut(String), allProvidersFailed([RefinementAttempt]), busy
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason), .invalidOutput(let reason), .unavailable(let reason): return reason
        case .timedOut(let provider): return "\(provider) timed out."
        case .allProvidersFailed(let attempts): return attempts.map { "\($0.providerID): \($0.message)" }.joined(separator: "\n")
        case .busy: return "A refinement is already running."
        }
    }
}
