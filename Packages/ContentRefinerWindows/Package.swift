// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContentRefinerWindows", platforms: [.macOS(.v15)],
    products: [.executable(name: "ContentRefinerWindows", targets: ["ContentRefinerWindows"])],
    dependencies: [.package(path: "../ContentRefinerBase"), .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.10.0")],
    targets: [.executableTarget(name: "ContentRefinerWindows", dependencies: [.product(name: "ContentRefinerBase", package: "ContentRefinerBase"), .product(name: "SwiftCrossUI", package: "swift-cross-ui"), .product(name: "DefaultBackend", package: "swift-cross-ui")])], swiftLanguageModes: [.v6])
