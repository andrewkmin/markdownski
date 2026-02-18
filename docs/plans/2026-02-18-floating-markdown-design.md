# Floating Markdown Overlay — Design Document

## Overview

A macOS floating markdown viewer/editor that behaves like the ChatGPT macOS popup. A borderless, always-on-top panel with a split layout: markdown input on top, live-rendered output below. Toggled via global hotkey.

## Architecture

**Pure AppKit + WKWebView**, single-target macOS app. No SwiftUI, no external dependencies.

### Why not SwiftUI?

- `NSHostingView` inside a borderless `NSPanel` has known focus and first-responder bugs
- Poor control over panel collection behavior and visibility across Spaces
- AppKit gives direct, predictable control over every panel behavior we need

## Component Structure

```
MarkdownFloat/
├── AppDelegate.swift            — App lifecycle, LSUIElement setup
├── HotkeyManager.swift          — Carbon RegisterEventHotKey wrapper
├── OverlayPanel.swift           — NSPanel subclass (borderless, floating, all Spaces)
├── OverlayViewController.swift  — Layout: input + divider + output
├── MarkdownRenderer.swift       — WKWebView + markdown-it, live rendering
├── Resources/
│   └── markdown-template.html   — HTML shell with inlined markdown-it + CSS
└── Info.plist                   — LSUIElement=YES
```

## Key Decisions

### 1. LSUIElement (no dock icon)

The app runs as a background utility. No dock icon, no menu bar icon. Just the hotkey and the panel.

### 2. Global Hotkey: Carbon RegisterEventHotKey

- Cmd+Shift+M toggles visibility
- No Accessibility permissions required
- Battle-tested API, works reliably across macOS versions

### 3. Markdown Rendering

A single `markdown-template.html` bundles:
- `markdown-it.min.js` (~30KB, inlined)
- CSS styles matching the spec
- A `renderMarkdown(text)` JS function

WKWebView loads the template once at startup. On input change, Swift calls `evaluateJavaScript("renderMarkdown(...)")` — no page reloads, no flicker.

Input is debounced at ~50ms to avoid hammering the web view during fast typing.

### 4. NSPanel Configuration

- Style: `.borderless | .nonactivatingPanel`
- `canBecomeKey = true` (accepts keyboard input)
- `canBecomeMain = false` (doesn't interfere with other apps)
- Level: `.floating`
- Collection behavior: `.canJoinAllSpaces | .fullScreenAuxiliary`
- Visible across all Spaces, does not hide on app switch

### 5. Animations

- Show: 120ms fade-in + slight upward translate (NSAnimationContext)
- Hide: 80ms fade-out
- ESC key hides panel (does not destroy)

### 6. Clipboard Pre-fill

On show, if `NSPasteboard.general` contains string content, pre-fill the input and render immediately.

## Layout

```
┌──────────────────────────────┐
│ Markdown Input    (~35-40%)  │  NSTextView, transparent bg
├──────────────────────────────┤
│ Subtle Divider (1px)         │
├──────────────────────────────┤
│ Rendered Output   (~60-65%)  │  WKWebView
└──────────────────────────────┘
```

- Width: 720px
- Height: ~75-80% of screen height
- Centered on screen
- 24px internal padding
- 16px rounded corners
- NSVisualEffectView with `.sidebar` material (blur background)
- Soft drop shadow

## Visual Spec

- Dark mode optimized
- System font, 15-16px input, 16px output
- Line height: 1.5 (input), 1.65 (output)
- Code blocks: monospace, soft bg tint, rounded corners, 12-16px padding
- Blockquotes: subtle left accent line, muted text
- Max content width in output: 640px

## Non-Goals (v1)

- File saving / persistence
- Multiple sessions
- Networking / APIs
- Syntax highlighting
- Resizable window
- Menu bar icon
