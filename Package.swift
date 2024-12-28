// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Getitem",
    platforms: [
      .macOS(.v13),   // Adjust the platform version as needed
    ],
    products: [
        .executable(
            name: "getitem",
            targets: ["Getitem"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Getitem",
            dependencies: [],
            path: "Sources/Getitem"
        ),
        .testTarget(
            name: "GetitemTests",
            dependencies: ["Getitem"],
            path: "Tests/GetitemTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
