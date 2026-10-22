// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Observation
import ContentRefinerCore

public struct RefinerProviderOption: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let availability: @Sendable () -> String
    public let makeBackend: @Sendable (String, String) -> any RefinementBackend
    public init(id: String, title: String, availability: @escaping @Sendable () -> String = { "Configured provider" },
                makeBackend: @escaping @Sendable (String, String) -> any RefinementBackend) {
        self.id = id; self.title = title; self.availability = availability; self.makeBackend = makeBackend
    }
    public static var http: Self {
        .init(id: "http", title: "HTTP model endpoint") { model, endpoint in
            HTTPRefinementBackend(id: "http", endpoint: URL(string: endpoint) ?? URL(fileURLWithPath: "/invalid"), model: model, headers: ProcessInfo.processInfo.environment["CONTENT_REFINER_API_KEY"].map { ["Authorization": "Bearer " + $0] } ?? [:])
        }
    }
}

public struct RefinerProviderSettings: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var providerID: String
    public var enabled: Bool
    public var model: String
    public var endpoint: String
    public init(id: String, providerID: String? = nil, enabled: Bool = true, model: String = "", endpoint: String = "") {
        self.id = id; self.providerID = providerID ?? id; self.enabled = enabled; self.model = model; self.endpoint = endpoint
    }
}

public struct RefinerPreferences: Codable, Sendable {
    public var providers: [RefinerProviderSettings]
    public var fallbackEnabled = true
    public var timeout = 90.0
    public init(providers: [RefinerProviderSettings]) { self.providers = providers }
}

@Observable @MainActor
public final class RefinerAppModel {
    public var original = ""
    public private(set) var current = ""
    public var directive = ""
    public var instruction = ""
    public var contentKind: String? = "auto"
    public var variationCount: Int? = 1
    public var selectedVariation: Int? = 1
    public private(set) var turns: [RefinementTurn] = []
    public private(set) var attempts: [RefinementAttempt] = []
    public private(set) var isRunning = false
    public private(set) var status = "Paste content and add an instruction"
    public var error: String?
    public var showSettings = false
    public var showHistory = false
    public var showGuidance = false
    public var timeoutText = "90"
    public var preferences: RefinerPreferences
    public let providerOptions: [RefinerProviderOption]
    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private var operation = UUID()

    public init(providers: [RefinerProviderOption] = [.http], defaults: UserDefaults = .standard) {
        self.providerOptions = providers
        self.defaults = defaults
        var preferences = RefinerPreferences(providers: providers.map { .init(id: $0.id, enabled: $0.id != "http" || providers.count == 1) })
        if let data = defaults.data(forKey: "ContentRefiner.preferences") {
            do {
                let saved = try JSONDecoder().decode(RefinerPreferences.self, from: data)
                preferences.fallbackEnabled = saved.fallbackEnabled
                guard saved.timeout.isFinite, (5...3600).contains(saved.timeout) else { throw ContentRefinerError.invalidInput("Saved timeout is invalid.") }; preferences.timeout = saved.timeout
                let supported = Set(providers.map(\.id))
                preferences.providers = saved.providers.filter { supported.contains($0.providerID) }
                for provider in providers where !preferences.providers.contains(where: { $0.id == provider.id }) {
                    preferences.providers.append(.init(id: provider.id, enabled: false))
                }
            } catch { self.error = "Could not load provider settings: \(error.localizedDescription)" }
        }
        self.preferences = preferences
        self.timeoutText = String(Int(preferences.timeout))
    }
    public var canRefine: Bool {
        !isRunning && !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!directive.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!turns.isEmpty && !instruction.isEmpty))
    }
    public var variations: [RefinementVariation] { turns.last?.result.output.variations ?? [] }
    public func saveSettings() {
        guard let timeout = Double(timeoutText), timeout.isFinite, (5...3600).contains(timeout),
              preferences.providers.contains(where: \.enabled) else { error = "Enable a provider and choose a timeout from 5 to 3600 seconds."; return }
        preferences.timeout = timeout
        do {
            defaults.set(try JSONEncoder().encode(preferences), forKey: "ContentRefiner.preferences")
            error = nil; showSettings = false; status = "Settings saved for the next request"
        } catch { self.error = error.localizedDescription }
    }
    public func refine() {
        guard canRefine else { return }
        let id = UUID(); operation = id; isRunning = true; error = nil; attempts = []
        let providers = preferences.providers.filter(\.enabled).compactMap { setting -> (any RefinementBackend)? in
            providerOptions.first { $0.id == setting.providerID }.map { NamedBackend(id: setting.id, wrapped: $0.makeBackend(setting.model, setting.endpoint)) }
        }
        let client = RefinementClient(backends: providers, configuration: .init(timeoutSeconds: preferences.timeout, fallbackEnabled: preferences.fallbackEnabled))
        let input = ContentRefinementInput(originalContent: original, latestContent: current.isEmpty ? original : current,
            userInstruction: directive.isEmpty ? instruction : directive, instruction: instruction,
            variationCount: variationCount ?? 1, contentKind: contentKind ?? "auto")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await client.refine(input) { [weak self] event in await self?.event(event, id: id) }
                try Task.checkCancellation()
                guard operation == id else { return }
                let previous = current.isEmpty ? original : current
                current = result.output.variations.first(where: { $0.index == 1 })?.content ?? ""
                instruction = result.output.instruction
                selectedVariation = 1
                turns.append(.init(directive: input.userInstruction, result: result))
                attempts = result.attempts; directive = ""
                status = "Round \(turns.count) completed with \(result.providerID) · \(current == previous ? "content unchanged" : "content updated")"
            } catch {
                guard operation == id else { return }
                self.error = Task.isCancelled || error is CancellationError ? nil : error.localizedDescription
                status = Task.isCancelled || error is CancellationError ? "Cancelled · previous content preserved" : "Failed · previous content preserved"
            }
            guard operation == id else { return }
            isRunning = false; task = nil
        }
    }
    private func event(_ event: RefinementEvent, id: UUID) {
        guard operation == id else { return }
        switch event {
        case .started(let provider): status = "Refining with \(provider)…"
        case .failed(let attempt): attempts.append(attempt); status = "\(attempt.providerID) failed · trying fallback"
        case .completed(let provider): status = "Completed with \(provider)"
        }
    }
    public func cancel() { task?.cancel() }
    public func reset() {
        guard !isRunning else { return }
        operation = UUID(); current = ""; original = ""; directive = ""; instruction = ""; turns = []; attempts = []; error = nil
        selectedVariation = 1; status = "Ready for new content"
    }
    public func chooseVariation(_ index: Int?) {
        guard !isRunning, let index, let variation = variations.first(where: { $0.index == index }) else { return }
        selectedVariation = index; current = variation.content
        turns[turns.count - 1].selectedVariation = index
    }
    public func load(_ url: URL) {
        guard !isRunning else { return }
        do { let content = try String(contentsOf: url, encoding: .utf8); reset(); original = content }
        catch { self.error = "Could not load UTF-8 text: \(error.localizedDescription)" }
    }
    public func export(_ url: URL) {
        do { try current.write(to: url, atomically: true, encoding: .utf8); status = "Exported \(url.lastPathComponent)" }
        catch { self.error = "Could not export: \(error.localizedDescription)" }
    }
    public func waitForRefinement() async { await task?.value }
}

private struct NamedBackend: RefinementBackend {
    let id: String
    let wrapped: any RefinementBackend
    func refine(_ input: ContentRefinementInput) async throws -> String { try await wrapped.refine(input) }
}

extension RefinerAppModel {
    public func addHTTPEndpoint() {
        var number = preferences.providers.filter { $0.providerID == "http" }.count + 1
        while preferences.providers.contains(where: { $0.id == "HTTP endpoint \(number)" }) { number += 1 }
        preferences.providers.append(.init(id: "HTTP endpoint \(number)", providerID: "http"))
    }
}
