import Foundation
import XCTest
import Synchronization
import ContentRefinerCore
@testable import ContentRefinerBase

private actor AppBackend: RefinementBackend {
    let id: String
    let fail: Bool
    var inputs: [ContentRefinementInput] = []
    init(_ id: String = "fixture", fail: Bool = false) { self.id = id; self.fail = fail }
    func refine(_ input: ContentRefinementInput) async throws -> String {
        inputs.append(input)
        if fail { throw ContentRefinerError.unavailable("Fixture unavailable") }
        let output = ContentRefinementOutput(variations: (1...input.variationCount).map {
            .init(index: $0, content: "Draft \(inputs.count) variation \($0)", notes: "Edited")
        }, instruction: "Preserve facts; improve clarity")
        return String(decoding: try JSONEncoder().encode(output), as: UTF8.self)
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    func testRepeatedRefinementCarriesSelectedVariationAndPreservesOriginal() async {
        let backend = AppBackend()
        let model = RefinerAppModel(providers: [.init(id: "fixture", title: "Fixture", makeBackend: { _, _ in backend })], defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.original = "Original"
        model.directive = "Improve clarity"
        model.variationCount = 2
        model.refine()
        await model.waitForRefinement()
        XCTAssertEqual(model.current, "Draft 1 variation 1")
        XCTAssertEqual(model.original, "Original")
        XCTAssertTrue(model.canRefine)
        model.chooseVariation(2)
        model.refine()
        await model.waitForRefinement()
        let inputs = await backend.inputs
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs[1].originalContent, "Original")
        XCTAssertEqual(inputs[1].latestContent, "Draft 1 variation 2")
        XCTAssertEqual(inputs[1].userInstruction, "Preserve facts; improve clarity")
        XCTAssertEqual(model.turns.count, 2)
    }

    func testFallbackAndSavedProviderSettingsAreVisibleAcrossReopen() async {
        let failed = AppBackend("failed", fail: true)
        let ready = AppBackend("ready")
        let options: [RefinerProviderOption] = [.init(id: "failed", title: "Failed", makeBackend: { _, _ in failed }), .init(id: "ready", title: "Ready", makeBackend: { _, _ in ready })]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = RefinerAppModel(providers: options, defaults: defaults)
        model.original = "Original"; model.directive = "Improve"
        model.refine(); await model.waitForRefinement()
        XCTAssertEqual(model.attempts.map(\.succeeded), [false, true])
        XCTAssertNil(model.error)
        model.preferences.providers.swapAt(0, 1)
        model.timeoutText = "20"
        model.saveSettings()
        let reopened = RefinerAppModel(providers: options, defaults: defaults)
        XCTAssertEqual(reopened.preferences.providers.first?.id, "ready")
        XCTAssertEqual(reopened.preferences.timeout, 20)
        model.timeoutText = "nan"
        model.saveSettings()
        XCTAssertNotNil(model.error)
        XCTAssertEqual(RefinerAppModel(providers: options, defaults: defaults).preferences.timeout, 20)
    }

    func testMultipleHTTPFallbacksKeepTheirTypeAndUniqueIDs() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = RefinerAppModel(defaults: defaults)
        model.addHTTPEndpoint(); model.addHTTPEndpoint()
        XCTAssertEqual(Set(model.preferences.providers.map(\.id)).count, 3)
        XCTAssertTrue(model.preferences.providers.allSatisfy { $0.providerID == "http" })
        model.saveSettings()
        let reopened = RefinerAppModel(defaults: defaults)
        XCTAssertEqual(reopened.preferences.providers.count, 3)
    }
    func testTopProviderModelChoicesPersistAndReachTheBackend() async {
        let models = Mutex<[String]>([])
        let backend = AppBackend()
        let options: [RefinerProviderOption] = [
            .init(id: "first", title: "First", makeBackend: { _, _ in backend }),
            .init(id: "chosen", title: "Chosen", modelIdentifiers: ["fast", "quality"], makeBackend: { model, _ in
                models.withLock { $0.append(model) }; return backend
            })
        ]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = RefinerAppModel(providers: options, defaults: defaults)
        model.preferences.providers[1].enabled = false
        model.selectPrimaryProvider(model.providerChoices.last)
        model.selectPrimaryModel("quality")
        model.setFallbackEnabled(false)
        XCTAssertEqual(model.primaryProvider?.id, "chosen")
        XCTAssertTrue(model.preferences.providers[0].enabled)
        let reopened = RefinerAppModel(providers: options, defaults: defaults)
        XCTAssertEqual(reopened.primaryModelChoice, "quality")
        XCTAssertFalse(reopened.preferences.fallbackEnabled)
        model.original = "Original"; model.instruction = "Preserve facts; improve clarity"
        XCTAssertTrue(model.canRefine)
        model.refine(); await model.waitForRefinement()
        XCTAssertEqual(models.withLock { $0 }, ["quality"])
        model.selectPrimaryModel("Custom model…"); model.setPrimaryModelText("private-model")
        XCTAssertTrue(model.usesCustomModel)
        XCTAssertEqual(RefinerAppModel(providers: options, defaults: defaults).primaryModelText, "private-model")
    }

    func testEditedConsolidatedInstructionsGuideTheNextPass() async {
        let backend = AppBackend()
        let model = RefinerAppModel(providers: [.init(id: "fixture", title: "Fixture", makeBackend: { _, _ in backend })], defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.original = "Original"; model.directive = "Improve"
        model.refine(); await model.waitForRefinement()
        model.instruction = "Keep a formal tone and preserve names"
        model.directive = "  "
        model.refine(); await model.waitForRefinement()
        let inputs = await backend.inputs
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs[1].instruction, "Keep a formal tone and preserve names")
        XCTAssertEqual(inputs[1].userInstruction, inputs[1].instruction)
        XCTAssertEqual(model.turns.count, 2)
    }

}
