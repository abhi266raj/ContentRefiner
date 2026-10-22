// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import ContentRefinerCore
#if os(Windows)
import ucrt
#elseif os(Linux)
import Glibc
#else
import Darwin
#endif

public enum ContentRefinerCommand {
public static let help = """
content-refiner \(ContentRefinerVersion.current)
Usage: content-refiner --input FILE --instruction TEXT --model NAME --endpoint URL [--endpoint FALLBACK_URL] [--timeout SECONDS]

Reads UTF-8 content, refines using configured OpenAI-compatible chat-completions endpoints in order,
and writes the first complete refined variation to stdout. Provider attempts/errors go to stderr.
Optional CONTENT_REFINER_API_KEY supplies a bearer token for every configured endpoint.
Only use fallback URLs authorized to receive the same content and token. CLI providers/on-device execution use the macOS demo.
"""
private static func log(_ text: String) { FileHandle.standardError.write(Data((text + "\n").utf8)) }

public static func run(arguments: [String] = Array(CommandLine.arguments.dropFirst())) async -> Int32 {
var arguments = arguments
if arguments.isEmpty || arguments.contains("--help") { print(help); return 0 }
if arguments == ["--version"] { print(ContentRefinerVersion.current); return 0 }
var values: [String: [String]] = [:]
while !arguments.isEmpty {
    let key = arguments.removeFirst()
    guard ["--input", "--instruction", "--model", "--endpoint", "--timeout"].contains(key), !arguments.isEmpty else { log(help); return 2 }
    values[key, default: []].append(arguments.removeFirst())
}
do {
    guard let path = values["--input"]?.first, let instruction = values["--instruction"]?.first,
          let model = values["--model"]?.first, let endpoints = values["--endpoint"], !endpoints.isEmpty else {
        throw ContentRefinerError.invalidInput(help)
    }
    let content = try String(contentsOfFile: path, encoding: .utf8)
    var headers: [String: String] = [:]
    if let key = ProcessInfo.processInfo.environment["CONTENT_REFINER_API_KEY"], !key.isEmpty { headers["Authorization"] = "Bearer \(key)" }
    let backends: [any RefinementBackend] = try endpoints.enumerated().map { index, endpoint in
        guard let url = URL(string: endpoint) else { throw ContentRefinerError.invalidInput("Invalid endpoint URL") }
        return HTTPRefinementBackend(id: "endpoint-\(index + 1)", endpoint: url, model: model, headers: headers)
    }
    let timeout = values["--timeout"]?.first.flatMap(Double.init) ?? 90
    let result = try await RefinementClient(backends: backends, configuration: .init(timeoutSeconds: timeout))
        .refine(.init(originalContent: content, userInstruction: instruction)) { event in
            switch event {
            case .started(let provider): log("Trying \(provider)")
            case .failed(let attempt): log("\(attempt.providerID): \(attempt.message)")
            case .completed(let provider): log("Completed with \(provider)")
            @unknown default: break
            }
        }
    print(result.output.variations[0].content)
    return 0
} catch { log(error.localizedDescription); return 1 }

}
}
