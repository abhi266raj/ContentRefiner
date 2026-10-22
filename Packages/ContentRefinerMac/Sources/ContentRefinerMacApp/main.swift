import SwiftCrossUI
import DefaultBackend
import ContentRefinerBase
import ContentRefinerMacProviders
@main struct ContentRefinerMacApp: App {
    @State var model = RefinerAppModel(providers: MacRefinerProviders.options)
    var body: some Scene {
        WindowGroup("Content Refiner") { ComparisonView(model: model) }
            .defaultSize(width: 1120, height: 780)
    }
}
