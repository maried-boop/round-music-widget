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
        .executableTarget(name: "RoundMusicWidget", resources: [
            .copy("Resources/orb-settings.json"),
            .copy("Resources/orb-shader.txt"),
            .copy("Resources/lens-map.rgba")
        ]),
        .executableTarget(name: "MusicLifecycleWatcher"),
        .testTarget(name: "RoundMusicWidgetTests", dependencies: ["RoundMusicWidget"],
                    resources: [.copy("Fixtures/original-lens.png")])
    ]
)
