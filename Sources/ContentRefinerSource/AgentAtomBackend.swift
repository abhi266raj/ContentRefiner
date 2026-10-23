// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import AgentAtomSource

/// Inject any AgentAtom session. Execution preserves the final raw response for caller inspection.
public struct AgentAtomRefinementBackend: RefinementBackend {
    public let id: String
    private let makeSession: @Sendable () throws -> any AgenticSessionProtocol
    private let strictSchema: Bool
    public init(id: String, strictSchema: Bool = true, makeSession: @escaping @Sendable () throws -> any AgenticSessionProtocol) {
        self.id = id; self.strictSchema = strictSchema; self.makeSession = makeSession
    }
    public func refine(_ input: ContentRefinementInput) async throws -> String {
        try input.validate()
        let session = try makeSession()
        let bridge = SchemaSession(underlying: session, strict: strictSchema)
        let operation = AgenticOperation(spec: ContentRefinerSpec(input: input), session: bridge)
        return try await withTaskCancellationHandler {
            try await operation.execute().get()
        } onCancel: { Task { await operation.cancel() } }
    }
}

private final class SchemaSession: AgenticSessionProtocol, Sendable {
    struct Configuration: Sendable {}
    let configuration = Configuration()
    let underlying: any AgenticSessionProtocol
    let strict: Bool
    var executionMetadata: [AgenticExecutionMetadata] { underlying.executionMetadata }
    init(underlying: any AgenticSessionProtocol, strict: Bool) { self.underlying = underlying; self.strict = strict }
    func respond(to input: String, instructions: String, schema: JSONString, for operation: ObjectIdentifier) async -> Result<String, AgenticError> {
        do {
            let prepared = strict ? try Self.normalize(schema) : schema
            return await underlying.respond(to: input, instructions: instructions, schema: prepared, for: operation)
        } catch { return .failure(.operationFailed(reason: error.localizedDescription)) }
    }
    private static func normalize(_ schema: JSONString) throws -> JSONString {
        func visit(_ value: Any) -> Any {
            if let array = value as? [Any] { return array.map(visit) }
            guard var object = value as? [String: Any] else { return value }
            for (key, value) in object { object[key] = visit(value) }
            if let properties = object["properties"] as? [String: Any] {
                object["additionalProperties"] = false
                object["required"] = properties.keys.sorted()
            }
            return object
        }
        let parsed = try JSONSerialization.jsonObject(with: Data(schema.rawValue.utf8))
        let data = try JSONSerialization.data(withJSONObject: visit(parsed), options: [.sortedKeys])
        guard let value = JSONString(String(decoding: data, as: UTF8.self)) else {
            throw ContentRefinerError.invalidInput("Could not prepare the response schema.")
        }
        return value
    }
}
