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

## Unsigned builds

markdownski is not code-signed or notarized (no Apple Developer account). On first launch, macOS Gatekeeper will block the app. To open it:

1. Right-click (or Control-click) the app
2. Select **Open** from the context menu
3. Click **Open** in the dialog

This only needs to be done once. Alternatively, build from source to avoid Gatekeeper entirely.
