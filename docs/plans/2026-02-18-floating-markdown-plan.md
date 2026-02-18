# Floating Markdown Overlay — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a polished macOS floating panel that renders markdown live as you type, toggled via Cmd+Shift+M.

**Architecture:** Pure AppKit app with NSPanel (borderless, floating, all Spaces), NSTextView for input, WKWebView for rendering via inlined markdown-it.js. Carbon API for global hotkey. LSUIElement (no dock icon).

**Tech Stack:** Swift, AppKit, WebKit, Carbon (EventHotKey)

**Security Note:** The WKWebView renders user-typed markdown locally — no network, no external input. HTML rendering is disabled in markdown-it config (`html: false`). The rendering is sandboxed within the WKWebView.

**Tech Lead Review Fixes Applied:**
- Resources moved inside Sources/ (SwiftPM `../` paths are disallowed)
- Dropped `.nonactivatingPanel`, use `NSApp.activate()` for keyboard input
- Text passed to JS via base64 encoding (eliminates escaping bugs)
- WKWebView transparency via `underPageBackgroundColor = .clear` (public API)
- `.app` bundle assembly via Makefile (Info.plist requires a bundle to work)

---

### Task 1: Scaffold the Project

**Files:**
- Create: `MarkdownFloat/Sources/main.swift`
- Create: `MarkdownFloat/Sources/AppDelegate.swift`
- Create: `MarkdownFloat/Info.plist`
- Create: `MarkdownFloat/Package.swift`
- Create: `MarkdownFloat/Makefile`

**Step 1: Create the project directory structure**

```bash
cd /Users/andrew/Code/andrewkmin/floating-markdown
mkdir -p MarkdownFloat/Sources/Resources
```

**Step 2: Create Info.plist**

Create `MarkdownFloat/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MarkdownFloat</string>
    <key>CFBundleIdentifier</key>
    <string>com.andrewkmin.MarkdownFloat</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>MarkdownFloat</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

**Step 3: Create main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 4: Create minimal AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MarkdownFloat launched")
    }
}
```

**Step 5: Create Package.swift**

Note: Resources live inside `Sources/Resources/` so SwiftPM can find them. Info.plist is excluded since it's not a source file.

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MarkdownFloat",
            path: ".",
            exclude: ["Info.plist", "Makefile"],
            sources: ["Sources"],
            resources: [
                .copy("Sources/Resources/markdown-template.html"),
                .copy("Sources/Resources/markdown-it.min.js")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
```

**Step 6: Create Makefile for .app bundle assembly**

```makefile
.PHONY: build run clean

build:
	swift build -c release
	mkdir -p MarkdownFloat.app/Contents/MacOS
	mkdir -p MarkdownFloat.app/Contents/Resources
	cp .build/release/MarkdownFloat MarkdownFloat.app/Contents/MacOS/
	cp Info.plist MarkdownFloat.app/Contents/
	@echo "Built MarkdownFloat.app"

run: build
	open MarkdownFloat.app

clean:
	swift package clean
	rm -rf MarkdownFloat.app
```

**Step 7: Build and verify**

```bash
cd /Users/andrew/Code/andrewkmin/floating-markdown/MarkdownFloat
swift build
```

Expected: Build succeeds (resource warnings about missing HTML/JS files are expected at this stage).

**Step 8: Commit**

```bash
git add .
git commit -m "feat: scaffold MarkdownFloat macOS app with SwiftPM"
```

---

### Task 2: OverlayPanel — Borderless Floating Panel

**Files:**
- Create: `MarkdownFloat/Sources/OverlayPanel.swift`
- Modify: `MarkdownFloat/Sources/AppDelegate.swift`

**Step 1: Create OverlayPanel subclass**

Key details:
- Style mask: `.borderless` only (no `.nonactivatingPanel` — it blocks keyboard input)
- `canBecomeKey = true`, `canBecomeMain = false`
- Level: `.floating`
- Collection behavior: `.canJoinAllSpaces | .fullScreenAuxiliary`
- `hidesOnDeactivate = false`
- `isMovableByWindowBackground = true`
- NSVisualEffectView with `.sidebar` material, 16px corner radius
- `show()` calls `NSApp.activate()` to ensure text input works
- ESC calls `cancelOperation` which triggers `hide()`
- `toggle()` switches between show/hide

```swift
import AppKit

class OverlayPanel: NSPanel {
    var overlayViewController: OverlayViewController?
    private var isAnimating = false

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panelWidth: CGFloat = 720
        let panelHeight: CGFloat = screen.visibleFrame.height * 0.75
        let originX = screen.frame.midX - panelWidth / 2
        let originY = screen.frame.midY - panelHeight / 2
        let frame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true

        let visualEffect = NSVisualEffectView(frame: frame)
        visualEffect.material = .sidebar
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        self.contentView = visualEffect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    func show() {
        guard !isAnimating else { return }
        isAnimating = true

        self.alphaValue = 0
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
    }

    func hide() {
        guard !isAnimating else { return }
        isAnimating = true

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.isAnimating = false
        })
    }

    func toggle() {
        if self.isVisible && self.alphaValue > 0 {
            hide()
        } else {
            show()
        }
    }
}
```

**Step 2: Wire panel into AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let panel = OverlayPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.show()
    }
}
```

**Step 3: Build and verify**

```bash
swift build && swift run
```

Expected: Floating, borderless, blurred panel appears centered. ESC hides it. Rounded corners and soft shadow visible.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add OverlayPanel with borderless floating behavior"
```

---

### Task 3: Layout — Input + Divider + Output

**Files:**
- Create: `MarkdownFloat/Sources/OverlayViewController.swift`
- Modify: `MarkdownFloat/Sources/OverlayPanel.swift` (add view controller)
- Modify: `MarkdownFloat/Sources/AppDelegate.swift`

**Step 1: Create OverlayViewController**

Split layout with:
- NSScrollView + NSTextView (top 37%, 24px padding)
- 1px NSView divider with `NSColor.separatorColor`
- WKWebView (bottom 63%) with `underPageBackgroundColor = .clear` and transparent HTML body
- NSTextViewDelegate for live text change
- 50ms debounce timer on text changes
- `renderMarkdown()` encodes text as base64, calls `renderMarkdown(atob('...'))` via evaluateJavaScript
- `focusInput()` and `prefillFromClipboard()` public methods
- NSTextView config: system font 15px, line spacing ~1.5, no rich text, no auto-substitutions

Base64 approach for JS injection (eliminates all escaping bugs):

```swift
private func renderMarkdown() {
    let text = textView.string
    let base64 = Data(text.utf8).base64EncodedString()
    webView.evaluateJavaScript("renderMarkdown(atob('\(base64)'))", completionHandler: nil)
}
```

**Step 2: Wire view controller into OverlayPanel**

In `OverlayPanel.init()`, after setting contentView:

```swift
let viewController = OverlayViewController()
viewController.view.frame = visualEffect.bounds
viewController.view.autoresizingMask = [.width, .height]
visualEffect.addSubview(viewController.view)
self.overlayViewController = viewController
```

Update `show()` to call `prefillFromClipboard()` before animation and `focusInput()` after.

**Step 3: Build and verify**

Expected: Panel shows with editable text area on top, web view below, thin divider between them. Typing works (keyboard input accepted).

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add split layout with input area, divider, and web view"
```

---

### Task 4: Markdown Rendering (HTML Template + markdown-it)

**Files:**
- Create: `MarkdownFloat/Sources/Resources/markdown-it.min.js` (downloaded from CDN)
- Create: `MarkdownFloat/Sources/Resources/markdown-template.html`
- Modify: `MarkdownFloat/Sources/OverlayViewController.swift` (load template on viewDidLoad)

**Step 1: Download markdown-it**

```bash
curl -o /Users/andrew/Code/andrewkmin/floating-markdown/MarkdownFloat/Sources/Resources/markdown-it.min.js \
  https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js
```

**Step 2: Create markdown-template.html**

Dark-themed HTML template with:
- `html, body { background: transparent; }` (required for WKWebView transparency)
- System font (`-apple-system`), 16px base, 1.65 line height
- Body text: `rgba(255, 255, 255, 0.88)`
- Headings: `rgba(255, 255, 255, 0.95)`, bold, slightly larger
- Code blocks: monospace (`SF Mono`), `rgba(255,255,255,0.06)` bg, rounded 8px, 14-16px padding
- Inline code: 0.88em, subtle bg `rgba(255,255,255,0.08)`, 4px radius
- Blockquotes: 3px left border at `rgba(255,255,255,0.2)`, text at `rgba(255,255,255,0.55)`
- Max content width: 640px, centered
- Empty state: `#content:empty::before` with "Start typing above..." placeholder
- `MARKDOWN_IT_JS_HERE` placeholder for inlined JS
- `renderMarkdown(text)` function: `md.render(text)` with config `{ html: false, linkify: true, typographer: true }`

**Step 3: Load template in OverlayViewController**

Add `loadMarkdownTemplate()`:
- Read `markdown-template.html` and `markdown-it.min.js` from `Bundle.module`
- Replace `MARKDOWN_IT_JS_HERE` placeholder with JS contents
- Call `webView.loadHTMLString(html, baseURL: nil)`
- Call at end of `viewDidLoad()`

**Step 4: Build and verify**

```bash
cd /Users/andrew/Code/andrewkmin/floating-markdown/MarkdownFloat
swift build && swift run
```

Expected: Type markdown in input, rendered output appears live below. Headings, code blocks, lists, blockquotes all render with dark theme.

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add live markdown rendering with markdown-it"
```

---

### Task 5: Global Hotkey (Cmd+Shift+M)

**Files:**
- Create: `MarkdownFloat/Sources/HotkeyManager.swift`
- Modify: `MarkdownFloat/Sources/AppDelegate.swift`

**Step 1: Create HotkeyManager**

Carbon-based hotkey:
- `kVK_ANSI_M` = `0x2E`, modifiers `cmdKey | shiftKey`
- `EventHotKeyID` with signature `OSType(0x4D464C54)` ("MFLT")
- `InstallEventHandler` on `GetApplicationEventTarget()`
- Calls `onToggle` closure when fired
- `UnregisterEventHotKey` in deinit
- Note: Carbon deprecation warnings are expected — suppress with `@available` or accept them. This API is still the standard pattern used by Rectangle, Raycast, Alfred, etc.

**Step 2: Wire into AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let panel = OverlayPanel()
    var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.panel.toggle()
        }
        // Panel stays hidden until hotkey — don't show on launch
    }
}
```

**Step 3: Build and verify**

```bash
swift build && swift run
```

Expected: App launches invisible. Cmd+Shift+M shows panel. ESC hides. Cmd+Shift+M toggles. Works across Spaces.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add global Cmd+Shift+M hotkey to toggle panel"
```

---

### Task 6: Visual Polish & Animation Refinement

**Files:**
- Modify: `MarkdownFloat/Sources/OverlayPanel.swift`

**Step 1: Add upward slide animation to show()**

Start frame 12px below final position, animate both alphaValue and frame:

```swift
let finalFrame = self.frame
var startFrame = finalFrame
startFrame.origin.y -= 12
self.setFrame(startFrame, display: false)
// ... then animate to finalFrame
```

**Step 2: Enhance shadow**

After setting `contentView`, configure layer shadow:

```swift
contentView.shadow = NSShadow()
contentView.layer?.shadowColor = NSColor.black.cgColor
contentView.layer?.shadowOpacity = 0.35
contentView.layer?.shadowOffset = CGSize(width: 0, height: -4)
contentView.layer?.shadowRadius = 20
```

**Step 3: Build and verify via .app bundle**

```bash
make run
```

Expected: Panel slides up + fades in. Shadow is soft and prominent. Rapid Cmd+Shift+M toggling doesn't break state. No dock icon (LSUIElement working via .app bundle).

**Step 4: Commit**

```bash
git add .
git commit -m "feat: polish animations and shadow styling"
```

---

### Task 7: Integration Testing & Edge Cases

**Step 1:** Test clipboard pre-fill — copy markdown, Cmd+Shift+M, verify pre-fill + render.

**Step 2:** Test rapid toggle — Cmd+Shift+M rapidly, verify no stuck states (isAnimating guard).

**Step 3:** Test large content — paste 1000+ line markdown, verify scroll and render performance.

**Step 4:** Test special characters — backticks, dollar signs, backslashes, template literals, emoji, Unicode — verify no rendering breakage (base64 approach should handle all).

**Step 5:** Test across Spaces — switch Spaces, verify panel follows.

**Step 6:** Test .app bundle — `make run`, verify no dock icon, proper LSUIElement behavior.

**Step 7:** Fix any issues found and commit.

```bash
git add .
git commit -m "fix: handle edge cases from integration testing"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Scaffold project + Makefile | 5 new |
| 2 | OverlayPanel (borderless, floating) | 1 new, 1 modify |
| 3 | Split layout (input + divider + output) | 1 new, 2 modify |
| 4 | Markdown rendering (markdown-it + HTML) | 2 new, 1 modify |
| 5 | Global hotkey (Carbon) | 1 new, 1 modify |
| 6 | Visual polish (animations, shadow) | 1 modify |
| 7 | Integration testing | varies |

Total: ~9 files, 7 incremental tasks with commits between each.
