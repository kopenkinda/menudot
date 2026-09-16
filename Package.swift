// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bartender",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Bartender", targets: ["Bartender"])],
    targets: [
        .executableTarget(name: "Bartender")
    ]
)
