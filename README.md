# Markdownski

Floating macOS overlay for fast text utilities, built with AppKit + WKWebView.

## What It Does

Markdownski opens a borderless floating panel with three tool modes:

1. Markdown
- Left: markdown editor
- Right: live rendered preview

2. Format JSON
- Left: raw JSON
- Right: prettified JSON (sorted keys)
- Invalid input shows parse errors

3. Parse/Stringify JSON
- Parse: JSON string literal to parsed JSON object/value
- Stringify: JSON object/value to escaped JSON string literal

## Current Features

- Global hotkey toggle: `Cmd+Shift+M`
- Borderless floating panel across Spaces
- Resizable window (min size enforced)
- Horizontal/vertical split toggle
- Auto-paste from clipboard toggle (default: off)
- Subtle close button (top-left) and `Esc` to dismiss
- Dark, translucent, ChatGPT/Apple-inspired styling
- Markdown preview styling aligned closely with GitHub dark markdown

## Quick Start

Requirements:
- macOS 13+
- Swift toolchain / Xcode Command Line Tools

Run directly:

```bash
cd MarkdownFloat
swift build
swift run
```

Build app bundle:

```bash
cd MarkdownFloat
make build
```

Launch app bundle:

```bash
cd MarkdownFloat
make run
```

## Usage

1. Launch the app.
2. Press `Cmd+Shift+M` to show/hide the panel.
3. Select a tool mode from the top segmented control.
4. Type or paste content in the left pane and read output on the right.

## Project Structure

- `MarkdownFloat/Sources/AppDelegate.swift` - app lifecycle
- `MarkdownFloat/Sources/HotkeyManager.swift` - global hotkey registration
- `MarkdownFloat/Sources/OverlayPanel.swift` - floating panel behavior
- `MarkdownFloat/Sources/OverlayViewController.swift` - UI layout and tool logic
- `MarkdownFloat/Resources/markdown-template.html` - markdown rendering template

## Notes

- Clipboard prefill only runs when the auto-paste toggle is enabled.
- No persistence/history yet.
- UI behavior has been manually smoke-tested; automated tests are not yet added.
