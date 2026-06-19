// swift-tools-version: 6.0
import PackageDescription

// KwizzCore holds the pure game logic (no SwiftUI/UIKit) so it can be built and
// verified on macOS. The SwiftUI app (in ../App) compiles these same sources
// into the app target via Xcode.
//
// - `KwizzCoreTests` (Swift Testing) runs inside Xcode where the test frameworks exist.
// - `KwizzCoreCheck` is a tiny executable that re-runs the same invariants using only
//   the standard library, so the logic can be verified from a plain Swift toolchain
//   (no Xcode) with `swift run KwizzCoreCheck`.
let package = Package(
    name: "KwizzCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "KwizzCore", targets: ["KwizzCore"]),
    ],
    targets: [
        .target(name: "KwizzCore", path: "Sources/KwizzCore"),
        .executableTarget(name: "KwizzCoreCheck", dependencies: ["KwizzCore"], path: "Dev/Check"),
        .testTarget(name: "KwizzCoreTests", dependencies: ["KwizzCore"], path: "Tests/KwizzCoreTests"),
    ]
)
