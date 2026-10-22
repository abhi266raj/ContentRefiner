// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Portable adapter for an explicitly configured OpenAI-compatible chat-completions endpoint.
public struct HTTPRefinementBackend: RefinementBackend {
    public let id: String
    public let endpoint: URL
    public let model: String
    private let headers: [String: String]
    public init(id: String, endpoint: URL, model: String, headers: [String: String] = [:]) {
        self.id = id; self.endpoint = endpoint; self.model = model; self.headers = headers
    }
    public func refine(_ input: ContentRefinementInput) async throws -> String {
        try input.validate()
        guard ["http", "https"].contains(endpoint.scheme?.lowercased() ?? ""), endpoint.host != nil, !model.isEmpty else {
            throw ContentRefinerError.invalidInput("An HTTP(S) chat-completions endpoint and model are required.")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let user = String(decoding: try JSONEncoder().encode(input), as: UTF8.self)
        let system = RefinementRules.instructions + "\nOutput keys: variations (array of {index: integer, content: string, notes: string}), detectedIssues (array of {category: string, description: string, correction: string}), instruction (string)."
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "response_format": ["type": "json_object"]
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw ContentRefinerError.unavailable("\(id) returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0).")
        }
        struct Completion: Decodable {
            struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
            let choices: [Choice]
        }
        guard let content = try JSONDecoder().decode(Completion.self, from: data).choices.first?.message.content else {
            throw ContentRefinerError.invalidOutput("The endpoint returned no refinement content.")
        }
        return content
    }
}
