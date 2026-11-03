// swift-tools-version: 6.0
// Pure Swift domain logic (D10). No SwiftUI/SwiftData, so tests run on Linux CI.
import PackageDescription

let package = Package(
    name: "DayTrackerCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "DayTrackerCore", targets: ["DayTrackerCore"]),
    ],
    targets: [
        .target(name: "DayTrackerCore"),
        // Fixtures are shared with the Python tests in analysis/ and read via #filePath.
        .testTarget(name: "DayTrackerCoreTests", dependencies: ["DayTrackerCore"], exclude: ["Fixtures"]),
    ]
)
