import SwiftCrossUI
import WinUIBackend
import ContentRefinerBase
@main struct ContentRefinerWindowsApp: App {
    @State var model = RefinerAppModel()
    var body: some Scene {
        WindowGroup("Content Refiner") { ComparisonView(model: model) }
            .defaultSize(width: 1120, height: 780)
    }
}
