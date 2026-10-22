// SPDX-License-Identifier: AGPL-3.0-only
import SwiftCrossUI

public struct ProviderSettingsPanel: View {
    @Bindable private var model: RefinerAppModel
    public init(model: RefinerAppModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Providers & fallback").font(.title2)
            Text("Enabled providers run in this order. Failed or timed-out attempts use the next provider.")
            Toggle("Try fallback providers automatically", isOn: $model.preferences.fallbackEnabled)
            HStack { Text("Timeout per provider (seconds)"); TextField("90", text: $model.timeoutText).frame(width: 100) }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(model.preferences.providers.indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(model.providerOptions.first { $0.id == model.preferences.providers[index].providerID }?.title ?? model.preferences.providers[index].id).font(.headline)
                                Toggle("Enabled", isOn: $model.preferences.providers[index].enabled)
                                Spacer()
                                Button("Up") { model.preferences.providers.swapAt(index, index - 1) }.disabled(index == 0)
                                Button("Down") { model.preferences.providers.swapAt(index, index + 1) }.disabled(index + 1 == model.preferences.providers.count)
                            }
                            Text(model.providerOptions.first { $0.id == model.preferences.providers[index].providerID }?.availability() ?? "Unknown provider").foregroundColor(.gray)
                            if model.preferences.providers[index].providerID != "apple" {
                                TextField("Model (provider default if blank)", text: $model.preferences.providers[index].model)
                                TextField(model.preferences.providers[index].providerID == "http" ? "Full chat-completions URL" : "Executable path (auto-detect if blank)", text: $model.preferences.providers[index].endpoint)
                            }
                            Divider()
                        }
                    }
                }
            }
            Text("Credentials stay with installed CLIs. HTTP providers may use CONTENT_REFINER_API_KEY from the app environment.").foregroundColor(.gray)
            Button("Add HTTP fallback endpoint") { model.addHTTPEndpoint() }
            Button("Save settings") { model.saveSettings() }
        }.disabled(model.isRunning)
    }
}
