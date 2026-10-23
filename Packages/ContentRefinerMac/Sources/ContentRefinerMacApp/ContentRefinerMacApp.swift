import SwiftCrossUI
import DefaultBackend
import AppKitBackend
import ContentRefinerBase
import ContentRefinerMacProviders
@main struct ContentRefinerMacApp: App {
    private let windowDelegate = StartupWindowDelegate()
    @State var model = RefinerAppModel(providers: MacRefinerProviders.options)
    var body: some Scene {
        WindowGroup("Content Refiner") { ComparisonView(model: model).inspectWindow { windowDelegate.install(on: $0) } }
            .defaultSize(width: 1120, height: 780)
    }
}
