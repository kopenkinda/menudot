// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuDot",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "MenuDot", targets: ["MenuDot"])],
    targets: [
        .executableTarget(name: "MenuDot")
    ]
)
