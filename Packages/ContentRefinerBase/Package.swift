// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContentRefinerBase", platforms: [.macOS(.v15)],
    products: [.library(name: "ContentRefinerBase", targets: ["ContentRefinerBase"])],
    dependencies: [.package(name: "ContentRefiner", path: "../.."), .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.10.0")],
    targets: [.target(name: "ContentRefinerBase", dependencies: [.product(name: "ContentRefinerCore", package: "ContentRefiner"), .product(name: "SwiftCrossUI", package: "swift-cross-ui")]), .testTarget(name: "ContentRefinerBaseTests", dependencies: ["ContentRefinerBase", .product(name: "ContentRefinerCore", package: "ContentRefiner")])], swiftLanguageModes: [.v6])
