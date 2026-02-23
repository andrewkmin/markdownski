# Distribution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship markdownski with a pre-built DMG download via GitHub Releases and clear build-from-source instructions.

**Architecture:** GitHub Actions workflow triggers on `v*` tags, builds a universal binary, packages it into a DMG, and attaches it to a GitHub Release. The Makefile gets `universal` and `dmg` targets for local builds.

**Tech Stack:** Swift 5.9 / SPM, GitHub Actions (`macos-14` runner), `hdiutil` for DMG creation.

---

### Task 1: Add universal and dmg targets to Makefile

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile**

Replace the entire Makefile with:

```makefile
.PHONY: build run clean universal dmg

build:
	swift build -c release
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@echo "Built markdownski.app"

universal:
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p markdownski.app/Contents/MacOS
	mkdir -p markdownski.app/Contents/Resources
	cp .build/apple/Products/Release/markdownski markdownski.app/Contents/MacOS/
	cp Info.plist markdownski.app/Contents/
	cp -R .build/apple/Products/Release/markdownski_markdownski.bundle markdownski.app/Contents/Resources/
	@echo "Built markdownski.app (universal)"

dmg: universal
	rm -f markdownski.dmg
	mkdir -p dmg-staging
	cp -R markdownski.app dmg-staging/
	ln -s /Applications dmg-staging/Applications
	hdiutil create -volname "markdownski" -srcfolder dmg-staging -ov -format UDZO markdownski.dmg
	rm -rf dmg-staging
	@echo "Built markdownski.dmg"

run: build
	open markdownski.app

clean:
	swift package clean
	rm -rf markdownski.app markdownski.dmg dmg-staging
```

**Step 2: Update .gitignore**

Add `markdownski.dmg` and `dmg-staging/` to `.gitignore`.

**Step 3: Test locally**

Run: `make dmg`
Expected: `markdownski.dmg` is created. Open it and verify the `.app` and `Applications` symlink appear.

**Step 4: Verify the app launches from DMG**

Run: `open markdownski.dmg` then double-click the app inside.
Expected: The floating panel appears when you press `Cmd+Shift+M`.

**Step 5: Clean up and commit**

```bash
make clean
git add Makefile .gitignore
git commit -m "feat: add universal and dmg Makefile targets"
```

---

### Task 2: Create GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create workflow file**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build universal binary
        run: make universal

      - name: Create DMG
        run: make dmg

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: markdownski.dmg
          generate_release_notes: true
```

**Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions release workflow"
```

---

### Task 3: Update README with install section

**Files:**
- Modify: `README.md`

**Step 1: Add Install and Security sections to README**

Insert an "Install" section right after the opening description (before "What It Does"), and add a "Security" section at the bottom (before "Notes"). The Install section should have:

1. **Download** — link to latest GitHub Release
2. **Gatekeeper note** — right-click > Open instructions for unsigned app
3. **Build from source** — the existing `swift build` / `make build` instructions (moved here)

Remove the separate "Quick Start" section since its content moves into "Install".

The full README after edits:

```markdown
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
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add install section and security link to README"
```

---

### Task 4: Tag v1.0.0 and push

**Step 1: Push all commits**

```bash
git push origin main
```

**Step 2: Create and push the tag**

```bash
git tag v1.0.0
git push origin v1.0.0
```

**Step 3: Verify**

Go to `https://github.com/andrewkmin/markdownski/actions` and confirm the release workflow runs.
Once complete, go to `https://github.com/andrewkmin/markdownski/releases` and confirm:
- A `v1.0.0` release exists
- `markdownski.dmg` is attached
- Release notes are auto-generated
