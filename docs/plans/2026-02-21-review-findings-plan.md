# Review Findings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Address all critical, important, and code quality findings from staff/senior-staff code reviews.

**Architecture:** Fix-by-fix approach starting with safety-critical HotkeyManager hardening, then OverlayPanel animation safety, OverlayViewController input handling, activation policy, and finally code quality refactors. Each fix is isolated and independently committable.

**Tech Stack:** Swift 5.9, macOS AppKit, Carbon Events API, Swift Package Manager

---

### Task 1: HotkeyManager — modifier validation + registration error checking (I1, C2)

Addresses two interrelated findings in HotkeyManager:
- **I1:** UserDefaults corruption can store `modifiers == 0`, registering a bare-key global hotkey that captures all presses of that key
- **C2:** `RegisterEventHotKey` return value is unchecked — if registration fails, user gets no feedback

**Files:**
- Modify: `MarkdownFloat/Lib/HotkeyManager.swift`
- Test: `MarkdownFloat/Tests/HotkeyManagerTests.swift`

**Step 1: Write failing tests for modifier validation**

Add to `HotkeyManagerTests.swift`:

```swift
final class HotkeyManagerModifierValidationTests: XCTestCase {

    func testHasRequiredModifierWithCommand() {
        XCTAssertTrue(HotkeyManager.hasRequiredModifier(UInt32(cmdKey)))
    }

    func testHasRequiredModifierWithControl() {
        XCTAssertTrue(HotkeyManager.hasRequiredModifier(UInt32(controlKey)))
    }

    func testHasRequiredModifierWithCommandShift() {
        XCTAssertTrue(HotkeyManager.hasRequiredModifier(UInt32(cmdKey) | UInt32(shiftKey)))
    }

    func testHasRequiredModifierWithControlOption() {
        XCTAssertTrue(HotkeyManager.hasRequiredModifier(UInt32(controlKey) | UInt32(optionKey)))
    }

    func testHasRequiredModifierWithZero() {
        XCTAssertFalse(HotkeyManager.hasRequiredModifier(0))
    }

    func testHasRequiredModifierWithShiftOnly() {
        XCTAssertFalse(HotkeyManager.hasRequiredModifier(UInt32(shiftKey)))
    }

    func testHasRequiredModifierWithOptionOnly() {
        XCTAssertFalse(HotkeyManager.hasRequiredModifier(UInt32(optionKey)))
    }

    func testHasRequiredModifierWithShiftOption() {
        XCTAssertFalse(HotkeyManager.hasRequiredModifier(UInt32(shiftKey) | UInt32(optionKey)))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd MarkdownFloat && swift test --filter HotkeyManagerModifierValidationTests 2>&1`
Expected: Compilation error — `hasRequiredModifier` doesn't exist yet

**Step 3: Implement modifier validation + registration error checking**

In `HotkeyManager.swift`:

1. Add static validation method:
```swift
public static func hasRequiredModifier(_ carbonModifiers: UInt32) -> Bool {
    return carbonModifiers & UInt32(cmdKey) != 0 || carbonModifiers & UInt32(controlKey) != 0
}
```

2. Add validation in `init()` after loading from UserDefaults — if modifiers are invalid, fall back to defaults:
```swift
if defaults.object(forKey: Self.keyCodeDefaultsKey) != nil {
    let loadedCode = UInt32(defaults.integer(forKey: Self.keyCodeDefaultsKey))
    let loadedMods = UInt32(defaults.integer(forKey: Self.modifiersDefaultsKey))
    if Self.hasRequiredModifier(loadedMods) {
        self.keyCode = loadedCode
        self.modifiers = loadedMods
    } else {
        self.keyCode = Self.defaultKeyCode
        self.modifiers = Self.defaultModifiers
        defaults.set(Int(Self.defaultKeyCode), forKey: Self.keyCodeDefaultsKey)
        defaults.set(Int(Self.defaultModifiers), forKey: Self.modifiersDefaultsKey)
    }
} else {
    self.keyCode = Self.defaultKeyCode
    self.modifiers = Self.defaultModifiers
}
```

3. Change `registerHotkey()` to return success/failure:
```swift
@discardableResult
private func registerHotkey() -> Bool {
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x4D464C54) // "MFLT"
    hotKeyID.id = 1

    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    guard status == noErr else {
        NSLog("RegisterEventHotKey failed with status %d for keyCode=0x%X modifiers=0x%X", status, keyCode, modifiers)
        return false
    }
    hotkeyRef = ref
    return true
}
```

4. Change `reregister` to return success and revert on failure:
```swift
@discardableResult
public func reregister(keyCode: UInt32, modifiers: UInt32) -> Bool {
    let previousKeyCode = self.keyCode
    let previousModifiers = self.modifiers

    unregisterHotkey()
    self.keyCode = keyCode
    self.modifiers = modifiers

    guard registerHotkey() else {
        self.keyCode = previousKeyCode
        self.modifiers = previousModifiers
        registerHotkey()
        return false
    }

    UserDefaults.standard.set(Int(keyCode), forKey: Self.keyCodeDefaultsKey)
    UserDefaults.standard.set(Int(modifiers), forKey: Self.modifiersDefaultsKey)
    return true
}
```

**Step 4: Run tests to verify they pass**

Run: `cd MarkdownFloat && swift test --filter HotkeyManagerModifierValidationTests 2>&1`
Expected: All 8 tests PASS

**Step 5: Run full test suite**

Run: `cd MarkdownFloat && swift test 2>&1`
Expected: All tests PASS

**Step 6: Commit**

```
git add MarkdownFloat/Lib/HotkeyManager.swift MarkdownFloat/Tests/HotkeyManagerTests.swift
git commit -m "fix: validate hotkey modifiers and check RegisterEventHotKey status (I1, C2)"
```

---

### Task 2: AppDelegate — change `var hotkeyManager` to `let` (C1)

`Unmanaged.passUnretained` in HotkeyManager holds a raw pointer. If `hotkeyManager` is reassigned, the pointer dangles causing use-after-free. Fix by making both properties `let` constants.

**Files:**
- Modify: `MarkdownFloat/Sources/AppDelegate.swift`

**Step 1: Restructure AppDelegate init**

Replace the entire file:

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let panel: OverlayPanel
    let hotkeyManager: HotkeyManager

    override init() {
        let p = OverlayPanel()
        self.panel = p
        self.hotkeyManager = HotkeyManager { [weak p] in
            p?.toggle()
        }
        super.init()
        panel.overlayViewController?.hotkeyManager = hotkeyManager
    }
}
```

Key changes:
- `panel` moved from default-value `let` to explicit init assignment (required so we can capture local `p`)
- `hotkeyManager` changed from `var?` to `let` (non-optional)
- Closure captures `panel` directly via local `p` (weak) instead of `self`
- No more `applicationDidFinishLaunching` needed — everything happens in `init()`

**Step 2: Build to verify compilation**

Run: `cd MarkdownFloat && swift build 2>&1`
Expected: BUILD SUCCEEDED

**Step 3: Run tests to verify no regressions**

Run: `cd MarkdownFloat && swift test 2>&1`
Expected: All tests PASS

**Step 4: Commit**

```
git add MarkdownFloat/Sources/AppDelegate.swift
git commit -m "fix: make hotkeyManager a let constant to prevent dangling pointer (C1)"
```

---

### Task 3: OverlayPanel — pending toggle + focusInput race fix (C3, I4)

Two related animation issues:
- **C3:** Rapid hotkey presses during 80-120ms animation are silently dropped
- **I4:** Delayed `focusInput` via `asyncAfter(0.13s)` can fire after panel starts hiding

**Files:**
- Modify: `MarkdownFloat/Sources/OverlayPanel.swift`

**Step 1: Add pendingToggle and move focusInput to completion handler**

Changes to OverlayPanel:

1. Add property: `private var pendingToggle = false`

2. Update `show()`:
```swift
func show() {
    guard !isAnimating else {
        pendingToggle = true
        return
    }
    pendingToggle = false
    isAnimating = true

    overlayViewController?.prefillFromClipboard()

    let finalFrame = self.frame
    var startFrame = finalFrame
    startFrame.origin.y -= 12
    self.setFrame(startFrame, display: false)

    self.alphaValue = 0
    self.orderFrontRegardless()
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.12
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.animator().alphaValue = visibleAlpha
        self.animator().setFrame(finalFrame, display: true)
    }, completionHandler: { [weak self] in
        self?.isAnimating = false
        self?.overlayViewController?.focusInput()
        self?.drainPendingToggle()
    })
}
```

3. Update `hide()`:
```swift
func hide() {
    guard !isAnimating else {
        pendingToggle = true
        return
    }
    overlayViewController?.cancelHotkeyRecordingIfActive()
    pendingToggle = false
    isAnimating = true

    NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.08
        context.timingFunction = CAMediaTimingFunction(name: .easeIn)
        self.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
        self?.orderOut(nil)
        self?.isAnimating = false
        self?.drainPendingToggle()
    })
}
```

4. Add drain helper:
```swift
private func drainPendingToggle() {
    guard pendingToggle else { return }
    pendingToggle = false
    toggle()
}
```

**Step 2: Build to verify compilation**

Run: `cd MarkdownFloat && swift build 2>&1`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
git add MarkdownFloat/Sources/OverlayPanel.swift
git commit -m "fix: handle toggle during animation and move focusInput to completion (C3, I4)"
```

---

### Task 4: OverlayViewController — forward Cmd+Q during recording + cursor tracking (I2, I5)

Two input handling issues:
- **I2:** Hotkey recording swallows ALL keyDown events including Cmd+Q — user can't quit without mouse
- **I5:** Click on shortcut chip pops cursor, then mouseExited pops again — cursor stack corruption

**Files:**
- Modify: `MarkdownFloat/Sources/OverlayViewController.swift`

**Step 1: Add `isCursorPushed` property**

Add after `private var chipRejectionWorkItem`:
```swift
private var isCursorPushed = false
```

**Step 2: Fix cursor push/pop tracking**

Replace `mouseEntered`:
```swift
override func mouseEntered(with event: NSEvent) {
    guard !isRecordingHotkey else { return }
    if !isCursorPushed {
        NSCursor.pointingHand.push()
        isCursorPushed = true
    }
    shortcutChip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.22).cgColor
}
```

Replace `mouseExited`:
```swift
override func mouseExited(with event: NSEvent) {
    if isCursorPushed {
        NSCursor.pop()
        isCursorPushed = false
    }
    if !isRecordingHotkey {
        shortcutChip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
    }
}
```

Replace `shortcutChipClicked`:
```swift
@objc
private func shortcutChipClicked(_ sender: NSClickGestureRecognizer) {
    guard !isRecordingHotkey else { return }
    if isCursorPushed {
        NSCursor.pop()
        isCursorPushed = false
    }
    startRecordingHotkey()
}
```

**Step 3: Forward Cmd+Q during hotkey recording**

Replace `startRecordingHotkey` event monitor setup:
```swift
private func startRecordingHotkey() {
    isRecordingHotkey = true
    shortcutLabel?.stringValue = "Type shortcut\u{2026}"
    shortcutChip.layer?.borderColor = Self.accentGreen.cgColor
    shortcutChip.layer?.borderWidth = 1.5

    hotkeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        // Forward Cmd+Q to the system so the user can always quit
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command] && event.keyCode == 0x0C {
            return event
        }
        self?.handleRecordedKey(event)
        return nil
    }
}
```

**Step 4: Use reregister return value for chip rejection**

Update `handleRecordedKey` — replace the `hotkeyManager?.reregister(...)` call and the two lines after it:
```swift
guard hotkeyManager?.reregister(keyCode: code, modifiers: carbonMods) == true else {
    showChipRejection("Shortcut unavailable")
    return
}
stopRecordingHotkey()
updateShortcutLabel()
```

**Step 5: Build to verify compilation**

Run: `cd MarkdownFloat && swift build 2>&1`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```
git add MarkdownFloat/Sources/OverlayViewController.swift
git commit -m "fix: forward Cmd+Q during recording and track cursor push/pop (I2, I5)"
```

---

### Task 5: Activation policy fallback (M8)

When run outside a `.app` bundle, `LSUIElement` from Info.plist isn't read, so the app shows in the Dock.

**Files:**
- Modify: `MarkdownFloat/Sources/main.swift`

**Step 1: Add setActivationPolicy**

Replace `main.swift`:
```swift
import AppKit

let app = NSApplication.shared
NSApp.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

**Step 2: Build to verify compilation**

Run: `cd MarkdownFloat && swift build 2>&1`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
git add MarkdownFloat/Sources/main.swift
git commit -m "fix: set accessory activation policy for non-bundle execution (M8)"
```

---

### Task 6: Extract JSONProcessor into testable module

OverlayViewController is ~1100 lines. The JSON processing logic is pure and can be extracted into a testable struct in `Lib/`.

**Files:**
- Create: `MarkdownFloat/Lib/JSONProcessor.swift`
- Test: `MarkdownFloat/Tests/JSONProcessorTests.swift`
- Modify: `MarkdownFloat/Sources/OverlayViewController.swift` (remove extracted logic, call JSONProcessor)

**Step 1: Write failing tests for JSONProcessor**

Create `MarkdownFloat/Tests/JSONProcessorTests.swift`:

```swift
import XCTest
@testable import MarkdownFloatLib

final class JSONProcessorFormatTests: XCTestCase {

    func testFormatValidJSON() {
        let result = JSONProcessor.formatJSON("{\"b\":2,\"a\":1}")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("\"a\" : 1"))
            XCTAssertTrue(output.contains("\"b\" : 2"))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testFormatInvalidJSON() {
        let result = JSONProcessor.formatJSON("{not json}")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error(let msg):
            XCTAssertTrue(msg.contains("Invalid JSON"))
        }
    }

    func testFormatEmptyString() {
        let result = JSONProcessor.formatJSON("")
        switch result {
        case .success:
            XCTFail("Expected error for empty input")
        case .error:
            break // expected
        }
    }
}

final class JSONProcessorParseTests: XCTestCase {

    func testParseValidStringLiteral() {
        // A JSON string containing escaped JSON
        let input = "\"{\\\"name\\\":\\\"Ada\\\"}\""
        let result = JSONProcessor.parseJSONString(input)
        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("\"name\""))
            XCTAssertTrue(output.contains("\"Ada\""))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testParseNonStringLiteral() {
        let result = JSONProcessor.parseJSONString("{\"a\":1}")
        switch result {
        case .success:
            XCTFail("Expected error — input is an object, not a string literal")
        case .error(let msg):
            XCTAssertTrue(msg.contains("JSON string literal"))
        }
    }
}

final class JSONProcessorStringifyTests: XCTestCase {

    func testStringifyValidObject() {
        let result = JSONProcessor.stringifyJSON("{\"a\":1}")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.hasPrefix("\""))
            XCTAssertTrue(output.hasSuffix("\""))
            XCTAssertTrue(output.contains("\\\"a\\\""))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testStringifyInvalidJSON() {
        let result = JSONProcessor.stringifyJSON("{bad}")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error(let msg):
            XCTAssertTrue(msg.contains("Invalid JSON"))
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd MarkdownFloat && swift test --filter JSONProcessor 2>&1`
Expected: Compilation error — `JSONProcessor` doesn't exist yet

**Step 3: Implement JSONProcessor**

Create `MarkdownFloat/Lib/JSONProcessor.swift`:

```swift
import Foundation

public enum JSONProcessor {

    public enum Result {
        case success(String)
        case error(String)
    }

    public static func formatJSON(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Invalid JSON.\nInput is empty.")
        }
        do {
            let value = try parseValue(from: input)
            let formatted = try encode(value: value, pretty: true)
            return .success(formatted)
        } catch {
            return .error("Invalid JSON.\n\(error.localizedDescription)")
        }
    }

    public static func parseJSONString(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Input is empty.")
        }
        do {
            let inner = try decodeStringLiteral(from: input)
            let value: Any
            do {
                value = try parseValue(from: inner)
            } catch {
                return .error("String value does not contain valid JSON.\n\(error.localizedDescription)")
            }
            let formatted = try encode(value: value, pretty: true)
            return .success(formatted)
        } catch {
            return .error("\(error.localizedDescription)")
        }
    }

    public static func stringifyJSON(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error("Input is empty.")
        }
        do {
            let value = try parseValue(from: input)
            let canonical = try encode(value: value, pretty: false)
            let encoded = try JSONEncoder().encode(canonical)
            return .success(String(decoding: encoded, as: UTF8.self))
        } catch {
            return .error("Invalid JSON value.\n\(error.localizedDescription)")
        }
    }

    // MARK: - Internal Helpers

    private static func parseValue(from text: String) throws -> Any {
        let data = Data(text.utf8)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func encode(value: Any, pretty: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
        if pretty { options.insert(.prettyPrinted) }
        let data = try JSONSerialization.data(withJSONObject: value, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeStringLiteral(from text: String) throws -> String {
        let data = Data(text.utf8)
        do {
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            let summary = "Input must be a JSON string literal, for example: \"{\\\"name\\\":\\\"Ada\\\"}\""
            throw StringLiteralError(message: "\(summary)\n\(error.localizedDescription)")
        }
    }

    private struct StringLiteralError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd MarkdownFloat && swift test --filter JSONProcessor 2>&1`
Expected: All 7 tests PASS

**Step 5: Wire JSONProcessor into OverlayViewController**

In `OverlayViewController.swift`:

1. Remove the private methods: `parseJSONValue(from:)`, `encodeJSON(value:pretty:)`, `decodeJSONStringLiteral(from:)`, and the `JSONToolError` enum.

2. Replace `renderJSONFormat()`:
```swift
private func renderJSONFormat() {
    let raw = textView.string
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        setOutputText(outputPlaceholderText(), kind: .placeholder)
        return
    }
    switch JSONProcessor.formatJSON(raw) {
    case .success(let text): setOutputText(text, kind: .normal)
    case .error(let msg): setOutputText(msg, kind: .error)
    }
}
```

3. Replace `renderJSONParse()`:
```swift
private func renderJSONParse() {
    let raw = textView.string
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        setOutputText(outputPlaceholderText(), kind: .placeholder)
        return
    }
    switch JSONProcessor.parseJSONString(raw) {
    case .success(let text): setOutputText(text, kind: .normal)
    case .error(let msg): setOutputText(msg, kind: .error)
    }
}
```

4. Replace `renderJSONStringify()`:
```swift
private func renderJSONStringify() {
    let raw = textView.string
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        setOutputText(outputPlaceholderText(), kind: .placeholder)
        return
    }
    switch JSONProcessor.stringifyJSON(raw) {
    case .success(let text): setOutputText(text, kind: .normal)
    case .error(let msg): setOutputText(msg, kind: .error)
    }
}
```

**Step 6: Build and run full test suite**

Run: `cd MarkdownFloat && swift test 2>&1`
Expected: All tests PASS

**Step 7: Commit**

```
git add MarkdownFloat/Lib/JSONProcessor.swift MarkdownFloat/Tests/JSONProcessorTests.swift MarkdownFloat/Sources/OverlayViewController.swift
git commit -m "refactor: extract JSONProcessor into testable module with unit tests"
```

---

### Task 7: Deduplicate text view factory + centralize constants + fix min width

Three related code quality items:
- `makeEditableTextView()` and `makeReadonlyTextView()` share ~18 lines
- Magic colors and layout numbers scattered across files
- Panel minSize (600) vs VC constraint (560) should use one source of truth

**Files:**
- Create: `MarkdownFloat/Sources/AppTheme.swift`
- Modify: `MarkdownFloat/Sources/OverlayViewController.swift`
- Modify: `MarkdownFloat/Sources/OverlayPanel.swift`

**Step 1: Create AppTheme with centralized constants**

Create `MarkdownFloat/Sources/AppTheme.swift`:

```swift
import AppKit

enum AppColors {
    static let accentGreen = NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.68, alpha: 0.95)

    // Text
    static let titleText = NSColor(calibratedWhite: 0.96, alpha: 0.98)
    static let subtitleText = NSColor(calibratedWhite: 0.80, alpha: 0.84)
    static let cardTitleText = NSColor(calibratedWhite: 0.82, alpha: 0.74)
    static let secondaryLabel = NSColor(calibratedWhite: 0.82, alpha: 0.78)
    static let chipLabel = NSColor(calibratedWhite: 0.92, alpha: 0.78)
    static let inputText = NSColor(calibratedWhite: 0.92, alpha: 0.96)
    static let outputText = NSColor(calibratedWhite: 0.90, alpha: 0.95)
    static let errorText = NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.56, alpha: 0.97)
    static let placeholderText = NSColor(calibratedWhite: 0.70, alpha: 0.55)
    static let outputPlaceholder = NSColor(calibratedWhite: 0.72, alpha: 0.58)
    static let iconDefault = NSColor(calibratedWhite: 1.0, alpha: 0.45)
    static let closeIcon = NSColor(calibratedWhite: 1.0, alpha: 0.70)
    static let clearAllText = NSColor(calibratedWhite: 0.82, alpha: 0.65)

    // Borders & Backgrounds
    static let chipBorder = NSColor(calibratedWhite: 1, alpha: 0.18)
    static let chipBorderDefault = NSColor(calibratedWhite: 1, alpha: 0.10)
    static let chipBorderHover = NSColor(calibratedWhite: 1, alpha: 0.22)
    static let chipBackground = NSColor(calibratedWhite: 1.0, alpha: 0.12)
    static let cardBorder = NSColor(calibratedWhite: 1, alpha: 0.08)
    static let panelBorder = NSColor(calibratedWhite: 1.0, alpha: 0.07)
    static let containerBackground = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.48)
    static let panelBackground = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.44)
    static let cardBackground = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 0.42)
}

enum Layout {
    static let outerPadding: CGFloat = 20
    static let splitSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 16
    static let panelCornerRadius: CGFloat = 22
    static let minimumPanelWidth: CGFloat = 600
    static let minimumPanelHeight: CGFloat = 420
    static let cardInnerPadding: CGFloat = 14
    static let cardTitleTopPadding: CGFloat = 12
}
```

**Step 2: Update OverlayPanel to use AppTheme**

Replace magic values in `OverlayPanel.swift` with `AppColors.*` and `Layout.*` references:
- `self.minSize` → use `Layout.minimumPanelWidth` and `Layout.minimumPanelHeight`
- Corner radius 22 → `Layout.panelCornerRadius`
- Border color → `AppColors.panelBorder`
- Background color → `AppColors.panelBackground`

**Step 3: Deduplicate text view factory in OverlayViewController**

Replace `makeEditableTextView()` and `makeReadonlyTextView()` with a single:
```swift
private func makeBaseTextView(editable: Bool) -> EditorTextView {
    let textContainer = NSTextContainer(size: NSSize(width: 0, height: .greatestFiniteMagnitude))
    textContainer.widthTracksTextView = true
    textContainer.heightTracksTextView = false

    let layoutManager = NSLayoutManager()
    layoutManager.addTextContainer(textContainer)

    let textStorage = NSTextStorage()
    textStorage.addLayoutManager(layoutManager)

    let tv = EditorTextView(frame: .zero, textContainer: textContainer)
    tv.isRichText = false
    tv.backgroundColor = .clear
    tv.drawsBackground = false
    tv.textContainerInset = NSSize(width: 0, height: 10)
    tv.isAutomaticQuoteSubstitutionEnabled = false
    tv.isAutomaticDashSubstitutionEnabled = false
    tv.isAutomaticTextReplacementEnabled = false
    tv.isHorizontallyResizable = false
    tv.isVerticallyResizable = true
    tv.autoresizingMask = [.width]
    tv.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    tv.minSize = .zero

    if editable {
        tv.insertionPointColor = AppColors.accentGreen
    } else {
        tv.isEditable = false
        tv.isSelectable = true
        tv.textColor = AppColors.outputText
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    return tv
}
```

Update call sites:
- `textView = makeBaseTextView(editable: true)`
- `outputTextView = makeBaseTextView(editable: false)`

**Step 4: Update OverlayViewController to use AppColors/Layout throughout**

Replace all inline color/layout literals with their AppColors/Layout equivalents.
Remove the `static let accentGreen` and `static let minimumPanelWidth` from OverlayViewController.
Use `Layout.minimumPanelWidth` for the width constraint (fixes the 560 vs 600 mismatch — now both panel and VC use 600).

**Step 5: Build and run full test suite**

Run: `cd MarkdownFloat && swift test 2>&1`
Expected: All tests PASS

**Step 6: Commit**

```
git add MarkdownFloat/Sources/AppTheme.swift MarkdownFloat/Sources/OverlayViewController.swift MarkdownFloat/Sources/OverlayPanel.swift
git commit -m "refactor: centralize colors/layout, deduplicate text view factory, fix min width"
```
