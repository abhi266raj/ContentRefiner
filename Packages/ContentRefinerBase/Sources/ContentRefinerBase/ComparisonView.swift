// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import SwiftCrossUI

/// Shared comparison surface; platform packages supply providers, not duplicated layouts.
public struct ComparisonView: View {
    @Bindable private var model: RefinerAppModel
    @Environment(\.chooseFile) private var chooseFile
    @Environment(\.chooseFileSaveDestination) private var chooseDestination
    public init(model: RefinerAppModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(Bundle.module.url(forResource: "ContentRefiner", withExtension: "png")!).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text("Content Refiner").font(.title).bold()
                    Text("One original. Better with every pass.").foregroundColor(.gray)
                }
                Spacer()
                Button("Open…") { Task { if let url = await chooseFile() { model.load(url) } } }.disabled(model.isRunning)
                Button("New session") { model.reset() }.disabled(model.isRunning)
                Button(model.showSettings ? "Back to content" : "Settings") { model.showSettings.toggle() }.disabled(model.isRunning)
            }
            if model.showSettings {
                ProviderSettingsPanel(model: model)
            } else {
                HStack {
                    Text("Content kind")
                    Picker(of: ["auto", "prose", "document", "email", "code", "script", "prompt"], selection: $model.contentKind).frame(width: 140)
                    Text("Variations")
                    Picker(of: [1, 2, 3, 4, 5], selection: $model.variationCount).frame(width: 80)
                    Spacer()
                    if !model.variations.isEmpty {
                        Text("View variation")
                        Picker(of: model.variations.map(\.index), selection: Binding(get: { model.selectedVariation }, set: { model.chooseVariation($0) })).frame(width: 80)
                        Button("Export…") { Task { if let url = await chooseDestination(defaultFileName: "Refined content.txt") { model.export(url) } } }
                    }
                }.disabled(model.isRunning)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 24) {
                            OriginalContentPane(model: model).frame(width: 300)
                            RefinedContentPane(content: model.current).frame(maxWidth: .infinity)
                        }
                        if !model.turns.isEmpty {
                            HStack {
                                Button(model.showGuidance ? "Hide instructions" : "Consolidated instructions") { model.showGuidance.toggle() }
                                Button(model.showHistory ? "Hide history" : "Changes & history (\(model.turns.count))") { model.showHistory.toggle() }
                            }
                            if model.showGuidance {
                                Text("Consolidated instructions").font(.headline)
                                TextEditor(text: $model.instruction).frame(height: 120).disabled(model.isRunning)
                            }
                            if model.showHistory { RefinementHistoryPanel(model: model) }
                        }
                        if model.attempts.contains(where: { !$0.succeeded }) {
                            Text("Provider attempts").font(.headline)
                            ForEach(Array(model.attempts.enumerated()), id: \.offset) { pair in
                                Text("\(pair.element.providerID): \(pair.element.message)").textSelectionEnabled()
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }
                RefinementToolbar(model: model)
            }
            if let error = model.error { Text(error).foregroundColor(.red).textSelectionEnabled() }
        }.padding(24).frame(minWidth: 900, minHeight: 680)
    }
}

public struct OriginalContentPane: View {
    @Bindable private var model: RefinerAppModel
    public init(model: RefinerAppModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original content").font(.headline)
            TextEditor(text: $model.original).frame(height: 340).disabled(model.isRunning || !model.turns.isEmpty)
            Text(model.turns.isEmpty ? "Paste text or open a UTF-8 file." : "Original preserved. Start a new session to replace it.").foregroundColor(.gray)
        }
    }
}

public struct RefinedContentPane: View {
    public let content: String
    public init(content: String) { self.content = content }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refined content").font(.headline)
            Text(content.isEmpty ? "Your complete refined content will appear here." : content)
                .textSelectionEnabled().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct RefinementToolbar: View {
    @Bindable private var model: RefinerAppModel
    public init(model: RefinerAppModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next refinement instruction").font(.headline)
            TextEditor(text: $model.directive).frame(height: 70).disabled(model.isRunning)
            HStack {
                Button(model.turns.isEmpty ? "Refine" : "Refine again") { model.refine() }.disabled(!model.canRefine)
                if model.isRunning { ProgressView(); Button("Cancel") { model.cancel() } }
                Text(model.status).foregroundColor(.gray)
                Spacer()
            }
            if !model.turns.isEmpty { Text("Leave the instruction blank to reuse consolidated guidance.").foregroundColor(.gray) }
        }
    }
}

public struct RefinementHistoryPanel: View {
    private let model: RefinerAppModel
    public init(model: RefinerAppModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(model.turns.enumerated()), id: \.offset) { pair in
                Text("Round \(pair.offset + 1) · \(pair.element.result.providerID)").font(.headline)
                Text(pair.element.directive).textSelectionEnabled()
                ForEach(pair.element.result.output.variations) { variation in Text("Variation \(variation.index): \(variation.notes)") }
                ForEach(Array(pair.element.result.output.detectedIssues.enumerated()), id: \.offset) { item in
                    Text("\(item.element.category): \(item.element.description)\n\(item.element.correction)").textSelectionEnabled()
                }
                Divider()
            }
        }
    }
}
