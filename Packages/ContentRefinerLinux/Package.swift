// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContentRefinerLinux", platforms: [.macOS(.v15)],
    products: [.executable(name: "ContentRefinerLinux", targets: ["ContentRefinerLinux"])],
    dependencies: [.package(path: "../ContentRefinerBase"), .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.10.0")],
    targets: [.executableTarget(name: "ContentRefinerLinux", dependencies: [.product(name: "ContentRefinerBase", package: "ContentRefinerBase"), .product(name: "SwiftCrossUI", package: "swift-cross-ui"), .product(name: "GtkBackend", package: "swift-cross-ui")])], swiftLanguageModes: [.v6])
