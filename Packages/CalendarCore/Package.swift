// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CalendarCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CalendarCore", targets: ["CalendarCore"])
    ],
    targets: [
        .target(
            name: "CalendarCore",
            resources: [.copy("Resources/BuiltInThemes")]
        ),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"])
    ]
)
