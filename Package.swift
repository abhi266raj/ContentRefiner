// swift-tools-version: 6.0
import PackageDescription

#if os(macOS)
let agentDependencies: [Package.Dependency] = [.package(url: "https://github.com/abhi266raj/AgentAtom.git", exact: "0.1.0")]
let sdkDependencies: [Target.Dependency] = ["ContentRefinerCore", .product(name: "AgentAtom", package: "AgentAtom")]
let sourceDependencies: [Target.Dependency] = ["ContentRefinerCore", .product(name: "AgentAtomSource", package: "AgentAtom")]
let excluded: [String] = []
let tests: [Target.Dependency] = ["ContentRefinerSource", .product(name: "AgentAtomSource", package: "AgentAtom")]
#else
let agentDependencies: [Package.Dependency] = []
let sdkDependencies: [Target.Dependency] = ["ContentRefinerCore"]
let sourceDependencies: [Target.Dependency] = ["ContentRefinerCore"]
let excluded = ["AgentAtomBackend.swift", "ContentRefinerSpec.swift"]
let tests: [Target.Dependency] = ["ContentRefinerSource"]
#endif

let package = Package(
    name: "ContentRefiner",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ContentRefiner", targets: ["ContentRefiner"]),
        .library(name: "ContentRefinerSource", targets: ["ContentRefinerSource"]),
        .library(name: "ContentRefinerCore", targets: ["ContentRefinerCore"]),
        .library(name: "ContentRefinerCommand", targets: ["ContentRefinerCommand"]),
        .executable(name: "content-refiner", targets: ["ContentRefinerCLI"])
    ],
    dependencies: agentDependencies,
    targets: [
        .target(name: "ContentRefinerCore", path: "Sources/ContentRefinerCore"),
        .target(name: "ContentRefiner", dependencies: sdkDependencies, exclude: excluded),
        .target(name: "ContentRefinerSource", dependencies: sourceDependencies, exclude: excluded),
        .target(name: "ContentRefinerCommand", dependencies: ["ContentRefinerCore"], path: "Packages/ContentRefinerCommand/Sources/ContentRefinerCommand"),
        .executableTarget(name: "ContentRefinerCLI", dependencies: ["ContentRefinerCommand"]),
        .testTarget(name: "ContentRefinerTests", dependencies: tests)
    ],
    swiftLanguageModes: [.v6]
)
