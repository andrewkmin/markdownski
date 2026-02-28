# Text Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add native find-in-document text search to the overlay panel using macOS NSTextFinder and WKWebView find interaction.

**Architecture:** Enable `usesFindBar` and `isIncrementalSearchingEnabled` on both NSTextViews (editor and output). Enable `isFindInteractionEnabled` on the WKWebView. Add Cmd+F handling to `EditorTextView.performKeyEquivalent`. The platform minimum is macOS 13, so no `@available` guards are needed.

**Tech Stack:** Swift 5.9, AppKit (NSTextFinder), WebKit (WKWebView find interaction)

---

### Task 1: Enable NSTextFinder on both text views

**Files:**
- Modify: `Sources/OverlayViewController.swift:675-710` (`makeBaseTextView`)

**Step 1: Add find bar properties to makeBaseTextView**

In `makeBaseTextView(editable:)`, add these two lines after `tv.minSize = .zero` (line 698) and before the `if editable` block (line 700):

```swift
tv.usesFindBar = true
tv.isIncrementalSearchingEnabled = true
```

**Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds with no errors.

**Step 3: Commit**

```bash
git add Sources/OverlayViewController.swift
git commit -m "feat: enable NSTextFinder find bar on editor and output text views"
```

---

### Task 2: Add Cmd+F keyboard shortcut to EditorTextView

**Files:**
- Modify: `Sources/OverlayViewController.swift:173-195` (`EditorTextView.performKeyEquivalent`)

**Step 1: Add Cmd+F case to the switch statement**

In `EditorTextView.performKeyEquivalent`, inside the `if flags == [.command]` switch block (after the `case "x"` line 182), add:

```swift
case "f":
    performFindPanelAction(#selector(NSTextFinder.Action.showFindInterface))
    return true
```

Wait — `performFindPanelAction` takes an `NSTextFinder.Action`. The correct invocation for an NSTextView is:

```swift
case "f":
    performTextFinderAction(nil)
    return true
```

Actually, the standard approach is to use the NSResponder method. NSTextView responds to `performFindPanelAction(_:)` when `usesFindBar` is true. The simplest correct approach:

```swift
case "f":
    NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: NSNumber(value: NSTextFinder.Action.showFindInterface.rawValue))
    return true
```

Hmm, that's awkward. The cleanest way in AppKit is:

```swift
case "f":
    if usesFindBar {
        performFindPanelAction(NSNumber(value: NSTextFinder.Action.showFindInterface.rawValue))
    }
    return true
```

**Note:** `performFindPanelAction(_:)` is inherited from NSTextView and expects the sender's `tag` to encode the action. When called directly, pass an `NSNumber` with the raw value of the desired `NSTextFinder.Action`. The value for `showFindInterface` is `1`.

The actual line to add in the `case "f"` inside the Cmd switch:

```swift
case "f":
    performFindPanelAction(NSMenuItem(title: "", action: nil, keyEquivalent: "").then { $0.tag = NSTextFinder.Action.showFindInterface.rawValue })
    return true
```

The simplest working approach — NSTextView's `performFindPanelAction` reads `sender.tag`:

```swift
case "f":
    let item = NSMenuItem()
    item.tag = NSTextFinder.Action.showFindInterface.rawValue
    performFindPanelAction(item)
    return true
```

**Step 2: Also add Cmd+G (find next) and Cmd+Shift+G (find previous)**

After the Cmd+F case, still inside the `if flags == [.command]` block, add:

```swift
case "g":
    let item = NSMenuItem()
    item.tag = NSTextFinder.Action.nextMatch.rawValue
    performFindPanelAction(item)
    return true
```

And in the existing `if flags == [.command, .shift]` block (line 189), before the `key == "z"` check, add:

```swift
if flags == [.command, .shift] {
    switch key {
    case "g":
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.previousMatch.rawValue
        performFindPanelAction(item)
        return true
    case "z":
        guard let um = undoManager, um.canRedo else { return super.performKeyEquivalent(with: event) }
        um.redo(); return true
    default: break
    }
}
```

**Step 3: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 4: Commit**

```bash
git add Sources/OverlayViewController.swift
git commit -m "feat: add Cmd+F/G find shortcuts to editor text view"
```

---

### Task 3: Enable find interaction on WKWebView

**Files:**
- Modify: `Sources/OverlayViewController.swift:401-456` (`setupPreviewCard`)

**Step 1: Enable isFindInteractionEnabled on the webView**

In `setupPreviewCard()`, after `webView.navigationDelegate = self` (line 413), add:

```swift
webView.isFindInteractionEnabled = true
```

**Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Sources/OverlayViewController.swift
git commit -m "feat: enable native find interaction on markdown preview webview"
```

---

### Task 4: Manual smoke test

**Step 1: Build and run the app**

Run: `make build && open markdownski.app`

**Step 2: Test find in editor**

1. Type some text in the editor
2. Press Cmd+F — find bar should appear at top of editor scroll view
3. Type a search term — matches should highlight
4. Press Cmd+G / Cmd+Shift+G — should cycle through matches
5. Press Escape — find bar should dismiss

**Step 3: Test find in JSON output**

1. Switch to "Format JSON" tab
2. Paste valid JSON — formatted output appears
3. Click in the output pane, press Cmd+F
4. Search for a key name — matches should highlight

**Step 4: Test find in markdown preview**

1. Switch to Markdown tab
2. Type some markdown text
3. Click in the preview pane, press Cmd+F
4. Search for text — native WKWebView find bar should appear

**Step 5: Commit all together if any fixups were needed**

```bash
git add -A
git commit -m "fix: address smoke test findings for text search"
```
