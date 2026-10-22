// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContentRefinerMac", platforms: [.macOS("26.0")],
    products: [.library(name: "ContentRefinerMacProviders", targets: ["ContentRefinerMacProviders"]), .executable(name: "ContentRefinerMac", targets: ["ContentRefinerMacApp"])],
    dependencies: [
        .package(name: "ContentRefiner", path: "../.."), .package(path: "../ContentRefinerBase"),
        .package(url: "https://github.com/abhi266raj/AgentAtom.git", exact: "0.1.0"),
        .package(url: "https://github.com/abhi266raj/TerminalAgentSession.git", exact: "0.1.4"),
        .package(url: "https://github.com/moreSwift/swift-cross-ui.git", exact: "0.10.0")
    ], targets: [
        .target(name: "ContentRefinerMacProviders", dependencies: [.product(name: "ContentRefiner", package: "ContentRefiner"), .product(name: "ContentRefinerBase", package: "ContentRefinerBase"), .product(name: "AgentAtom", package: "AgentAtom"), .product(name: "TerminalAgentSession", package: "TerminalAgentSession")]),
        .executableTarget(name: "ContentRefinerMacApp", dependencies: ["ContentRefinerMacProviders", .product(name: "ContentRefinerBase", package: "ContentRefinerBase"), .product(name: "SwiftCrossUI", package: "swift-cross-ui"), .product(name: "DefaultBackend", package: "swift-cross-ui")])
    ], swiftLanguageModes: [.v6])
