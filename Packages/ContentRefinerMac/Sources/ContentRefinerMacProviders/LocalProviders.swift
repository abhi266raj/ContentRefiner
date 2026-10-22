// SPDX-License-Identifier: AGPL-3.0-only
#if os(macOS)
import Foundation
import AgentAtom
import TerminalAgentSession
import ContentRefiner

public enum LocalRefinementProvider: String, CaseIterable, Codable, Sendable, Identifiable {
    case codex, claude, antigravity, grok, apple
    public var id: String { rawValue }
    public var title: String { self == .apple ? "Apple Intelligence" : rawValue.capitalized }
    public var executable: String { self == .antigravity ? "agy" : rawValue }
}

public struct LocalProviderConfiguration: Codable, Sendable, Equatable, Identifiable {
    public var provider: LocalRefinementProvider
    public var enabled: Bool
    public var model: String
    public var executablePath: String
    public var id: String { provider.id }
    public init(provider: LocalRefinementProvider, enabled: Bool = true, model: String = "", executablePath: String = "") {
        self.provider = provider; self.enabled = enabled; self.model = model; self.executablePath = executablePath
    }
    public var availability: String {
        if provider == .apple {
            if #available(macOS 26, *) { return AppleIntelligenceSession() == nil ? "On-device model unavailable" : "On-device model ready" }
            return "Requires macOS 26 or later"
        }
        return resolvedExecutable == nil ? "CLI not found" : "CLI installed; sign-in is checked when running"
    }
    fileprivate var resolvedExecutable: URL? {
        let manager = FileManager.default
        if !executablePath.isEmpty {
            let url = URL(fileURLWithPath: (executablePath as NSString).expandingTildeInPath)
            return manager.isExecutableFile(atPath: url.path) ? url : nil
        }
        let paths = ["/opt/homebrew/bin", "/usr/local/bin"] + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin").components(separatedBy: ":")
        return paths.map { URL(fileURLWithPath: $0).appendingPathComponent(provider.executable) }.first { manager.isExecutableFile(atPath: $0.path) }
    }
    public func backend() -> any RefinementBackend { LocalProviderBackend(configuration: self) }
}

private struct LocalProviderBackend: RefinementBackend {
    let configuration: LocalProviderConfiguration
    var id: String { configuration.id }
    func refine(_ input: ContentRefinementInput) async throws -> String {
        if configuration.provider == .apple {
            guard #available(macOS 26, *) else { throw ContentRefinerError.unavailable("Apple Intelligence requires macOS 26 or later.") }
            return try await AgentAtomRefinementBackend(id: id, strictSchema: false, makeSession: {
                guard let session = AppleIntelligenceSession() else {
                    throw ContentRefinerError.unavailable("Enable Apple Intelligence and wait for its on-device model to be ready.")
                }
                return session
            }).refine(input)
        }
        guard let executable = configuration.resolvedExecutable else {
            throw ContentRefinerError.unavailable("\(configuration.provider.executable) was not found. Install its CLI and sign in, or set its executable path in Settings.")
        }
        let files = FileManager.default
        let workspace = files.temporaryDirectory.appendingPathComponent("content-refiner-\(UUID().uuidString)")
        try files.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: workspace) }
        let launcher = workspace.appendingPathComponent("run-cli")
        func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let paths = [executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").components(separatedBy: ":")
        let script = """
        #!/bin/bash
        set -o pipefail
        export PATH=\(quote(paths.joined(separator: ":")))
        arguments=()
        for argument in "$@"; do
          case "$argument" in
            --dangerously-skip-permissions) ;;
            --schema) arguments+=(\(configuration.provider == .grok ? "'--json-schema'" : "'--schema'"));;
            *) arguments+=("$argument");;
          esac
        done
        exec \(quote(executable.path)) "${arguments[@]}" </dev/null

        """
        try Data(script.utf8).write(to: launcher)
        try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
        guard let provider = TerminalAgentSession.standardProviders.first(where: { $0.name == configuration.provider.rawValue }) else {
            throw ContentRefinerError.unavailable("Unsupported terminal provider.")
        }
        let arguments: [String]
        switch configuration.provider {
        case .codex: arguments = ["--skip-git-repo-check"]
        case .grok: arguments = ["--single"]
        default: arguments = []
        }
        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let settings = TerminalAgentConfiguration(executablePath: launcher.path, model: model.isEmpty ? nil : model,
            workingDirectory: workspace, extraArguments: arguments, additionalSearchPaths: paths,
            metadata: [.modelIdentifier, .duration], persistenceMode: .ephemeral)
        guard let session = TerminalAgentSession(provider: provider, configuration: settings) else {
            throw ContentRefinerError.unavailable("Could not start \(configuration.provider.title).")
        }
        defer { session.purgeMemory() }
        return try await withTaskCancellationHandler {
            try await AgentAtomRefinementBackend(id: id, makeSession: { session }).refine(input)
        } onCancel: { session.purgeMemory() }
    }
}
#endif

#if os(macOS)
import ContentRefinerBase
public enum MacRefinerProviders {
    public static var options: [RefinerProviderOption] {
        LocalRefinementProvider.allCases.map { provider in
            RefinerProviderOption(id: provider.id, title: provider.title, availability: {
                LocalProviderConfiguration(provider: provider).availability
            }, makeBackend: { model, path in
                LocalProviderConfiguration(provider: provider, model: model, executablePath: path).backend()
            })
        } + [.http]
    }
}
#endif
