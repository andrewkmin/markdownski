# Security Review

markdownski is a local-only macOS utility. It **does not connect to the internet** and **does not send any data anywhere**.

This document summarizes a line-by-line audit of the entire codebase.

## Findings

| Category | Status | Details |
|---|---|---|
| Network access | None | Zero use of `URLSession`, `URLRequest`, `fetch()`, `XMLHttpRequest`, `WebSocket`, or any networking API. |
| File system | Bundle only | The only file reads are `Bundle.module.url(forResource:)` to load its own bundled HTML template and JavaScript. No writes to disk. |
| Clipboard | Local only | Reads clipboard when auto-paste is enabled; writes to clipboard via copy buttons. Data never leaves the app. |
| IPC / XPC | None | No inter-process communication, `NSTask`, `Process`, or `DistributedNotification`. |
| Third-party dependencies | None | `Package.swift` has zero external packages. Only Apple system frameworks: AppKit, WebKit, Carbon. |
| Entitlements | Minimal | `Info.plist` declares only bundle metadata and `LSUIElement` (menu-bar accessory). No entitlements for network, contacts, location, camera, microphone, or file access. |
| JavaScript (WKWebView) | Sandboxed | The markdown preview uses a bundled `markdown-it.min.js` inlined at build time. No external scripts are loaded. The WKWebView is created with `baseURL: nil` (preventing network requests from content) and `html: false` in the markdown-it config (escaping raw HTML tags to block `<script>` or `<img>` injection). |
| UserDefaults | Preferences only | Stores four UI preferences locally: auto-paste toggle, split mode, tool mode, and hotkey binding. |

## How to verify

The codebase is small enough to audit manually. To confirm there are no networking APIs:

```bash
grep -rn 'URLSession\|URLRequest\|NSURLConnection\|fetch(\|XMLHttpRequest\|WebSocket\|NWConnection' Sources/ Lib/ Resources/
```

This should return zero results.

## Distribution

Releases are built automatically by [GitHub Actions](.github/workflows/release.yml) when a version tag is pushed. The pipeline:

1. Runs the full test suite (`swift test`)
2. Builds a universal binary (arm64 + x86_64) with bundle version injected from the git tag
3. Validates the `.app` bundle (binary, plist, and resource bundle assertions)
4. Packages it into a DMG and publishes a SHA-256 checksum alongside it

All GitHub Actions are pinned by commit SHA to prevent supply chain attacks via mutable tags. The build job runs with read-only repository permissions; only the release job (which uploads artifacts) has write access.

### Verifying your download

Each release includes a `.sha256` checksum file. To verify:

```bash
shasum -a 256 -c markdownski.dmg.sha256
```

### Unsigned builds

markdownski is not code-signed or notarized (no Apple Developer account). On first launch, macOS Gatekeeper will block the app because it cannot verify the developer identity. To open it:

1. Right-click (or Control-click) the app
2. Select **Open** from the context menu
3. Click **Open** in the dialog
4. If the dialog does not appear, go to **System Settings > Privacy & Security** and click **Open Anyway**

This only needs to be done once. Alternatively, build from source to avoid Gatekeeper entirely.
