// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AgentIndicator", platforms: [.macOS(.v14)],
    products: [.executable(name: "AgentIndicator", targets: ["AgentIndicator"]), .executable(name: "LEDProbe", targets: ["LEDProbe"])],
    targets: [.executableTarget(name: "AgentIndicator"), .executableTarget(name: "LEDProbe")],
    swiftLanguageModes: [.v5]
)
