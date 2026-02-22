// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MarkdownFloatLib",
            path: "Lib",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "MarkdownFloat",
            dependencies: ["MarkdownFloatLib"],
            path: ".",
            exclude: ["Info.plist", "Makefile", "MarkdownFloat.app", "Lib", "Tests"],
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
            name: "MarkdownFloatTests",
            dependencies: ["MarkdownFloatLib"],
            path: "Tests"
        )
    ]
)
