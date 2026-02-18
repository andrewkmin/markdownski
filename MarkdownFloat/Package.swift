// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MarkdownFloat",
            path: ".",
            exclude: ["Info.plist", "Makefile", "MarkdownFloat.app"],
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
        )
    ]
)
