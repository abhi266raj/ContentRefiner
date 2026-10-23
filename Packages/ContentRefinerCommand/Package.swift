// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContentRefinerCommand",
    products: [.library(name: "ContentRefinerCommand", targets: ["ContentRefinerCommand"])],
    dependencies: [.package(name: "ContentRefiner", path: "../..")],
    targets: [.target(name: "ContentRefinerCommand", dependencies: [.product(name: "ContentRefinerCore", package: "ContentRefiner")])], swiftLanguageModes: [.v6])
