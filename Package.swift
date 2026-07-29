// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "USBBench",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "USBBench", targets: ["USBBenchApp"]),
    .executable(name: "USBBenchProbe", targets: ["USBBenchProbe"]),
  ],
  targets: [
    .target(
      name: "USBBenchCore",
      linkerSettings: [
        .linkedLibrary("sqlite3"),
        .linkedFramework("IOKit"),
      ]
    ),
    .executableTarget(
      name: "USBBenchApp",
      dependencies: ["USBBenchCore"]
    ),
    .executableTarget(
      name: "USBBenchProbe",
      dependencies: ["USBBenchCore"]
    ),
    .testTarget(
      name: "USBBenchCoreTests",
      dependencies: ["USBBenchCore"]
    ),
  ],
  swiftLanguageModes: [.v5]
)
