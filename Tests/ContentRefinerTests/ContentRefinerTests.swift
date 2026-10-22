// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import XCTest
import Synchronization
#if canImport(ContentRefinerSource)
import AgentAtomSource
@testable import ContentRefinerSource
#else
@testable import ContentRefiner
#endif

private func response(_ contents: [String] = ["Refined content"], instruction: String = "Keep facts and improve clarity") throws -> String {
    let output = ContentRefinementOutput(variations: contents.enumerated().map { .init(index: $0.offset + 1, content: $0.element, notes: "Improved clarity") }, instruction: instruction)
    return String(decoding: try JSONEncoder().encode(output), as: UTF8.self)
}

private actor Backend: RefinementBackend {
    let id: String
    let raw: String
    let fail: Bool
    let delay: Duration?
    var inputs: [ContentRefinementInput] = []
    init(_ id: String, raw: String = "", fail: Bool = false, delay: Duration? = nil) { self.id = id; self.raw = raw; self.fail = fail; self.delay = delay }
    func refine(_ input: ContentRefinementInput) async throws -> String {
        inputs.append(input)
        if let delay { try await Task.sleep(for: delay) }
        if fail { throw ContentRefinerError.unavailable("Fixture unavailable") }
        return raw
    }
}

private actor GateBackend: RefinementBackend {
    let id = "gate"
    let raw: String
    private var pending: CheckedContinuation<Void, Never>?
    private var waiting: CheckedContinuation<Void, Never>?
    init(raw: String) { self.raw = raw }
    func refine(_ input: ContentRefinementInput) async throws -> String {
        await withCheckedContinuation { pending = $0; waiting?.resume(); waiting = nil }
        return raw
    }
    func waitUntilRunning() async { if pending != nil { return }; await withCheckedContinuation { waiting = $0 } }
    func release() { pending?.resume(); pending = nil }
}

#if canImport(AgentAtomSource)
private final class RecordingSession: AgenticSessionProtocol, Sendable {
    struct Configuration: Sendable {}
    let configuration = Configuration()
    var executionMetadata: [AgenticExecutionMetadata] { [] }
    let values = Mutex<(String, String, String)>(("", "", ""))
    let raw: String
    init(raw: String) { self.raw = raw }
    func respond(to input: String, instructions: String, schema: JSONString, for operation: ObjectIdentifier) async -> Result<String, AgenticError> {
        values.withLock { $0 = (input, instructions, schema.rawValue) }
        return .success(raw)
    }
}

#endif

final class ContentRefinerTests: XCTestCase {
    #if canImport(AgentAtomSource)
    func testTypedSpecVersionInputSeparationAndInjectedAgentAtomSession() async throws {
        let session = RecordingSession(raw: try response())
        let backend = AgentAtomRefinementBackend(id: "injected", makeSession: { session })
        let input = ContentRefinementInput(originalContent: "Original email", userInstruction: "Make it concise", contentKind: "email")
        let result = try await RefinementClient(backends: [backend]).refine(input)
        XCTAssertEqual(ContentRefinerSpec.identity.id, "ContentRefiner")
        XCTAssertEqual(ContentRefinerSpec.identity.version, "0.1.0")
        XCTAssertEqual(result.rawResponse, session.raw)
        let recorded = session.values.withLock { $0 }
        XCTAssertTrue(recorded.0.contains("Original email"))
        XCTAssertFalse(recorded.1.contains("Original email"))
        XCTAssertTrue(recorded.1.contains("immutable"))
        let schema = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(recorded.2.utf8)) as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual(Set(schema["required"] as? [String] ?? []), Set(["variations", "detectedIssues", "instruction"]))
    }

    #endif

    func testFallbackAfterUnavailableMalformedAndInvalidVariationCount() async throws {
        let bad = Backend("offline", fail: true)
        let malformed = Backend("malformed", raw: "not json")
        let incomplete = Backend("incomplete", raw: try response(["Only one"]))
        let good = Backend("good", raw: try response(["First", "Second"]))
        let input = ContentRefinementInput(originalContent: "Original", userInstruction: "Improve", variationCount: 2)
        let result = try await RefinementClient(backends: [bad, malformed, incomplete, good]).refine(input)
        XCTAssertEqual(result.providerID, "good")
        XCTAssertEqual(result.attempts.map(\.succeeded), [false, false, false, true])
        XCTAssertEqual(result.output.variations.count, 2)
        let goodInputs = await good.inputs
        XCTAssertEqual(goodInputs, [input])
    }

    func testFallbackCanBeDisabledAndFailuresAreExplicit() async throws {
        let first = Backend("first", fail: true)
        let second = Backend("second", raw: try response())
        do {
            _ = try await RefinementClient(backends: [first, second], configuration: .init(fallbackEnabled: false))
                .refine(.init(originalContent: "Original", userInstruction: "Improve"))
            XCTFail("Failure must surface")
        } catch ContentRefinerError.allProvidersFailed(let attempts) {
            XCTAssertEqual(attempts.map(\.providerID), ["first"])
        }
        let inputs = await second.inputs
        XCTAssertTrue(inputs.isEmpty)
    }

    func testTimeoutUsesNextProvider() async throws {
        let slow = Backend("slow", raw: try response(), delay: .seconds(60))
        let ready = Backend("ready", raw: try response())
        let result = try await RefinementClient(backends: [slow, ready], configuration: .init(timeoutSeconds: 0.01))
            .refine(.init(originalContent: "Original", userInstruction: "Improve"))
        XCTAssertEqual(result.providerID, "ready")
        XCTAssertTrue(result.attempts[0].message.contains("timed out"))
    }

    func testCancellationNeverFallsBackOrCommitsLateContent() async throws {
        let gate = GateBackend(raw: try response())
        let fallback = Backend("fallback", raw: try response())
        let session = try RefinementSession(originalContent: "Original", client: .init(backends: [gate, fallback]))
        let running = Task { try await session.refine("Improve") }
        await gate.waitUntilRunning()
        running.cancel()
        await gate.release()
        do { _ = try await running.value; XCTFail("Cancelled refinement must fail") } catch is CancellationError {}
        let snapshot = await session.snapshot
        XCTAssertEqual(snapshot.latestContent, "Original")
        XCTAssertTrue(snapshot.turns.isEmpty)
        let fallbackInputs = await fallback.inputs
        XCTAssertTrue(fallbackInputs.isEmpty)
    }

    func testIterativeSessionPreservesOriginalAndUsesSelectedVariationAndGuidance() async throws {
        let backend = Backend("test", raw: try response(["First", "Selected"]))
        let session = try RefinementSession(originalContent: "Immutable original", client: .init(backends: [backend]))
        _ = try await session.refine("Shorten", variationCount: 2)
        try await session.selectVariation(2)
        _ = try await session.refine("", variationCount: 2)
        let inputs = await backend.inputs
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs[1].originalContent, "Immutable original")
        XCTAssertEqual(inputs[1].latestContent, "Selected")
        XCTAssertEqual(inputs[1].userInstruction, "Keep facts and improve clarity")
        let snapshot = await session.snapshot
        XCTAssertEqual(snapshot.turns.count, 2)
        XCTAssertEqual(snapshot.turns[0].selectedVariation, 2)
    }

    func testConcurrentSessionRefinementIsRejected() async throws {
        let gate = GateBackend(raw: try response())
        let session = try RefinementSession(originalContent: "Original", client: .init(backends: [gate]))
        let running = Task { try await session.refine("Improve") }
        await gate.waitUntilRunning()
        do { _ = try await session.refine("Conflict"); XCTFail("Must reject concurrent turns") } catch ContentRefinerError.busy {}
        await gate.release()
        _ = try await running.value
    }

    func testInvalidInputAndConfigurationDoNotReachProvider() async throws {
        let backend = Backend("test", raw: try response())
        for input in [ContentRefinementInput(originalContent: " ", userInstruction: "Improve"),
                      .init(originalContent: "Original", userInstruction: " "),
                      .init(originalContent: "Original", userInstruction: "Improve", variationCount: 0)] {
            do { _ = try await RefinementClient(backends: [backend]).refine(input); XCTFail("Invalid input") } catch ContentRefinerError.invalidInput {}
        }
        do {
            _ = try await RefinementClient(backends: [backend], configuration: .init(timeoutSeconds: .nan))
                .refine(.init(originalContent: "Original", userInstruction: "Improve"))
            XCTFail("NaN timeout")
        } catch ContentRefinerError.invalidInput {}
        let inputs = await backend.inputs
        XCTAssertTrue(inputs.isEmpty)
    }
}
