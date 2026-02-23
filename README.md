# markdownski

Floating macOS overlay for fast text utilities, built with AppKit + WKWebView.

## Install

**Download:** Grab the latest `.dmg` from [Releases](https://github.com/andrewkmin/markdownski/releases/latest), open it, and drag `markdownski.app` to Applications.

> **Note:** markdownski is not code-signed. On first launch, macOS will block it. Right-click the app, select **Open**, then click **Open** in the dialog. This only needs to be done once.

**Build from source** (requires macOS 13+, Swift 5.9+):

```bash
git clone https://github.com/andrewkmin/markdownski.git
cd markdownski
make build && open markdownski.app
```

## What It Does

markdownski opens a borderless floating panel with four tool modes:

1. **Markdown** — editor on the left, live rendered preview on the right
2. **Format JSON** — paste raw JSON, get prettified output (sorted keys, validation errors inline)
3. **Parse JSON** — unwrap a JSON string literal into a formatted JSON object
4. **Stringify JSON** — wrap a JSON value into an escaped string literal

## Features

- **Global hotkey** — `Cmd+Shift+M` by default; click the shortcut chip in the top bar to rebind
- Borderless floating panel that follows you across Spaces
- Resizable window with enforced minimum size
- Horizontal / vertical split toggle
- Auto-paste from clipboard (default: off)
- Close button (top-left) and `Esc` to dismiss
- Dark, translucent UI with vibrancy effects
- Markdown preview styled to match GitHub dark mode
- Animated pill tab bar for switching tool modes
- Copy buttons on both editor and output panes

## Usage

1. Launch the app (it runs as a menu-bar accessory — no Dock icon).
2. Press `Cmd+Shift+M` to show/hide the panel.
3. Click the shortcut chip (top-right) to rebind the hotkey to any `Cmd` or `Ctrl` combo.
4. Pick a tool mode from the pill tab bar.
5. Type or paste content in the left pane; output appears on the right.

## Project Structure

```
├── Sources/
│   ├── main.swift                  # app entry point
│   ├── AppDelegate.swift           # app lifecycle, wires panel + hotkey
│   ├── AppTheme.swift              # centralized colors (AppColors) and layout constants
│   ├── OverlayPanel.swift          # floating NSPanel with show/hide animations
│   └── OverlayViewController.swift # UI layout, tool modes, hotkey recording
├── Lib/
│   ├── HotkeyManager.swift         # global hotkey via Carbon Events API
│   └── JSONProcessor.swift         # format / parse / stringify JSON helpers
├── Tests/
│   ├── HotkeyManagerTests.swift    # unit tests for hotkey display + validation
│   └── JSONProcessorTests.swift    # unit tests for all JSON operations
├── Resources/
│   ├── markdown-template.html      # HTML template for markdown preview
│   └── markdown-it.min.js          # bundled markdown-it renderer
├── Package.swift                   # SPM manifest (markdownski + markdownskiLib)
└── Makefile                        # build / run / clean shortcuts
```

## Running Tests

```bash
swift test
```

## Security

This app makes **zero network connections** and has **no external dependencies**. See [SECURITY.md](SECURITY.md) for a full audit.

## Notes

- Clipboard prefill only runs when the auto-paste toggle is enabled.
- Preferences (hotkey binding, split mode, tool mode, auto-paste) are persisted via `UserDefaults`.
