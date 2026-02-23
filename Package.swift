// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "markdownski",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "markdownskiLib",
            path: "Lib",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "markdownski",
            dependencies: ["markdownskiLib"],
            path: ".",
            exclude: ["Info.plist", "Makefile", "markdownski.app", "Lib", "Tests", "docs", "README.md", "SECURITY.md", ".gitignore"],
            sources: ["Sources"],
            resources: [
                .copy("Resources/markdown-template.html"),
                .copy("Resources/markdown-it.min.js")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "markdownskiTests",
            dependencies: ["markdownskiLib"],
            path: "Tests"
        )
    ]
)
