// swift-tools-version: 5.9
import PackageDescription

// SurBox: offline native macOS harmonium. Rendering, state and real-time audio
// remain separate. Real recordings must have documented redistribution rights;
// the app must explicitly identify any procedural reed fallback.
let package = Package(
    name: "SurBox",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SurBox", targets: ["SurBox"])],
    targets: [
        .target(name: "SurBoxCore"),
        .target(name: "SurBoxDSP", publicHeadersPath: "include"),
        .executableTarget(name: "SurBox", dependencies: ["SurBoxCore", "SurBoxDSP"], resources: [.process("Resources")]),
        .testTarget(name: "SurBoxCoreTests", dependencies: ["SurBoxCore", "SurBoxDSP"])
    ],
    cxxLanguageStandard: .cxx17
)
