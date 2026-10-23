// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import SwiftCrossUI

public struct RefinerProviderChoice: Equatable, Sendable, CustomStringConvertible {
    public let id: String
    public let title: String
    public var description: String { title }
}

extension RefinerAppModel {
    public var providerChoices: [RefinerProviderChoice] {
        preferences.providers.map { setting in
            .init(id: setting.id, title: setting.id != setting.providerID ? setting.id : providerOptions.first { $0.id == setting.providerID }?.title ?? setting.id)
        }
    }
    private var primaryIndex: Int? { preferences.providers.firstIndex(where: \.enabled) }
    public var primaryProvider: RefinerProviderChoice? {
        guard let primaryIndex else { return nil }
        return providerChoices.first { $0.id == preferences.providers[primaryIndex].id }
    }
    public var primaryOption: RefinerProviderOption? {
        guard let primaryIndex else { return nil }
        return providerOptions.first { $0.id == preferences.providers[primaryIndex].providerID }
    }
    public var primaryModelText: String {
        guard let primaryIndex else { return "" }
        return preferences.providers[primaryIndex].model
    }
    public var primaryModelOptions: [String] {
        ["Provider default"] + Array(Set(primaryOption?.modelIdentifiers ?? [])).sorted() + ["Custom model…"]
    }
    public var usesCustomModel: Bool {
        editingCustomModel || (!primaryModelText.isEmpty && !(primaryOption?.modelIdentifiers.contains(primaryModelText) ?? false))
    }
    public var primaryModelChoice: String? { usesCustomModel ? "Custom model…" : primaryModelText.isEmpty ? "Provider default" : primaryModelText }
    public func selectPrimaryProvider(_ choice: RefinerProviderChoice?) {
        guard !isRunning, let choice, let index = preferences.providers.firstIndex(where: { $0.id == choice.id }) else { return }
        var setting = preferences.providers.remove(at: index)
        setting.enabled = true
        preferences.providers.insert(setting, at: 0)
        editingCustomModel = false
        persistProviderPreferences()
    }
    public func selectPrimaryModel(_ choice: String?) {
        guard !isRunning, let choice, primaryModelOptions.contains(choice) else { return }
        editingCustomModel = choice == "Custom model…"
        if !editingCustomModel { setPrimaryModelText(choice == "Provider default" ? "" : choice) }
    }
    public func setPrimaryModelText(_ text: String) {
        guard !isRunning, let primaryIndex else { return }
        preferences.providers[primaryIndex].model = text
        persistProviderPreferences()
    }
    public func setFallbackEnabled(_ enabled: Bool) {
        guard !isRunning else { return }
        preferences.fallbackEnabled = enabled
        persistProviderPreferences()
    }
    private func persistProviderPreferences() {
        do { defaults.set(try JSONEncoder().encode(preferences), forKey: "ContentRefiner.preferences") }
        catch { self.error = "Could not save provider preferences: \(error.localizedDescription)" }
    }
}

public struct PrimaryProviderControls: View {
    @Bindable private var model: RefinerAppModel
    public init(model: RefinerAppModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Provider")
                Picker(of: model.providerChoices, selection: Binding(get: { model.primaryProvider }, set: { model.selectPrimaryProvider($0) })).frame(width: 180)
                Text("Model")
                if model.primaryOption?.id == "apple" {
                    Text("On-device model")
                } else {
                    Picker(of: model.primaryModelOptions, selection: Binding(get: { model.primaryModelChoice }, set: { model.selectPrimaryModel($0) })).frame(width: 200)
                    if model.usesCustomModel {
                        TextField("Model identifier", text: Binding(get: { model.primaryModelText }, set: { model.setPrimaryModelText($0) })).frame(minWidth: 160, maxWidth: .infinity)
                    }
                }
                Spacer()
            }
            Text(model.primaryOption.map { model.availability(for: $0) } ?? "Configure a provider in Settings").foregroundColor(.gray)
        }.disabled(model.isRunning)
    }
}
