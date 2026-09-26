// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "RoundMusicWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RoundMusicWidget",
            targets: ["RoundMusicWidget"]
        ),
        .executable(
            name: "MusicLifecycleWatcher",
            targets: ["MusicLifecycleWatcher"]
        )
    ],
    targets: [
        .executableTarget(name: "RoundMusicWidget"),
        .executableTarget(name: "MusicLifecycleWatcher")
    ]
)
