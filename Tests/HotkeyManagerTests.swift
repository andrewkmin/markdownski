import XCTest
import Carbon
import AppKit
@testable import markdownskiLib

final class HotkeyManagerKeyNameTests: XCTestCase {

    // MARK: - keyName(for:) — Letter keys

    func testKeyNameLetterKeys() {
        let expected: [(UInt32, String)] = [
            (0x00, "A"), (0x01, "S"), (0x02, "D"), (0x03, "F"),
            (0x04, "H"), (0x05, "G"), (0x06, "Z"), (0x07, "X"),
            (0x08, "C"), (0x09, "V"), (0x0B, "B"), (0x0C, "Q"),
            (0x0D, "W"), (0x0E, "E"), (0x0F, "R"), (0x10, "Y"),
            (0x11, "T"), (0x1F, "O"), (0x20, "U"), (0x22, "I"),
            (0x23, "P"), (0x25, "L"), (0x26, "J"), (0x28, "K"),
            (0x2D, "N"), (0x2E, "M"),
        ]
        for (code, name) in expected {
            XCTAssertEqual(
                HotkeyManager.keyName(for: code), name,
                "Key code 0x\(String(code, radix: 16, uppercase: true)) should map to \(name)"
            )
        }
    }

    // MARK: - keyName(for:) — Number keys

    func testKeyNameNumberKeys() {
        let expected: [(UInt32, String)] = [
            (0x12, "1"), (0x13, "2"), (0x14, "3"), (0x15, "4"),
            (0x17, "5"), (0x16, "6"), (0x1A, "7"), (0x1C, "8"),
            (0x19, "9"), (0x1D, "0"),
        ]
        for (code, name) in expected {
            XCTAssertEqual(
                HotkeyManager.keyName(for: code), name,
                "Key code 0x\(String(code, radix: 16, uppercase: true)) should map to \(name)"
            )
        }
    }

    // MARK: - keyName(for:) — Punctuation & symbol keys

    func testKeyNamePunctuationKeys() {
        let expected: [(UInt32, String)] = [
            (0x18, "="), (0x1B, "-"), (0x1E, "]"), (0x21, "["),
            (0x27, "'"), (0x29, ";"), (0x2A, "\\"), (0x2B, ","),
            (0x2C, "/"), (0x2F, "."), (0x32, "`"),
        ]
        for (code, name) in expected {
            XCTAssertEqual(
                HotkeyManager.keyName(for: code), name,
                "Key code 0x\(String(code, radix: 16, uppercase: true)) should map to \(name)"
            )
        }
    }

    // MARK: - keyName(for:) — Special keys

    func testKeyNameSpecialKeys() {
        XCTAssertEqual(HotkeyManager.keyName(for: 0x30), "⇥", "Tab key")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x31), "Space", "Space bar")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x33), "⌫", "Delete (backspace)")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x24), "↩", "Return")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x35), "⎋", "Escape")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x75), "⌦", "Forward delete")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x73), "↖", "Home")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x77), "↘", "End")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x74), "⇞", "Page up")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x79), "⇟", "Page down")
    }

    // MARK: - keyName(for:) — Arrow keys

    func testKeyNameArrowKeys() {
        XCTAssertEqual(HotkeyManager.keyName(for: 0x7E), "↑", "Up arrow")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x7D), "↓", "Down arrow")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x7B), "←", "Left arrow")
        XCTAssertEqual(HotkeyManager.keyName(for: 0x7C), "→", "Right arrow")
    }

    // MARK: - keyName(for:) — Function keys

    func testKeyNameFunctionKeys() {
        let expected: [(UInt32, String)] = [
            (0x7A, "F1"), (0x78, "F2"), (0x63, "F3"), (0x76, "F4"),
            (0x60, "F5"), (0x61, "F6"), (0x62, "F7"), (0x64, "F8"),
            (0x65, "F9"), (0x6D, "F10"), (0x67, "F11"), (0x6F, "F12"),
        ]
        for (code, name) in expected {
            XCTAssertEqual(
                HotkeyManager.keyName(for: code), name,
                "Key code 0x\(String(code, radix: 16, uppercase: true)) should map to \(name)"
            )
        }
    }

    // MARK: - keyName(for:) — Unknown / edge cases

    func testKeyNameUnknownCodeReturnsQuestionMark() {
        // 0x0A is not in the table (gap between V=0x09 and B=0x0B)
        XCTAssertEqual(HotkeyManager.keyName(for: 0x0A), "?")
    }

    func testKeyNameVeryHighCodeReturnsQuestionMark() {
        XCTAssertEqual(HotkeyManager.keyName(for: 0xFF), "?")
    }

    func testKeyNameMaxUInt32ReturnsQuestionMark() {
        XCTAssertEqual(HotkeyManager.keyName(for: UInt32.max), "?")
    }

    func testKeyNameAnotherGapReturnsQuestionMark() {
        // 0x34 is between ⌫=0x33 and ⎋=0x35 — not mapped
        XCTAssertEqual(HotkeyManager.keyName(for: 0x34), "?")
    }
}

// MARK: - carbonModifiers(from:)

final class HotkeyManagerCarbonModifiersTests: XCTestCase {

    func testCommandOnly() {
        let result = HotkeyManager.carbonModifiers(from: .command)
        XCTAssertEqual(result, UInt32(cmdKey))
    }

    func testShiftOnly() {
        let result = HotkeyManager.carbonModifiers(from: .shift)
        XCTAssertEqual(result, UInt32(shiftKey))
    }

    func testOptionOnly() {
        let result = HotkeyManager.carbonModifiers(from: .option)
        XCTAssertEqual(result, UInt32(optionKey))
    }

    func testControlOnly() {
        let result = HotkeyManager.carbonModifiers(from: .control)
        XCTAssertEqual(result, UInt32(controlKey))
    }

    func testCommandShift() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let result = HotkeyManager.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(cmdKey) | UInt32(shiftKey))
    }

    func testControlOption() {
        let flags: NSEvent.ModifierFlags = [.control, .option]
        let result = HotkeyManager.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(controlKey) | UInt32(optionKey))
    }

    func testAllFourModifiers() {
        let flags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let result = HotkeyManager.carbonModifiers(from: flags)
        let expected = UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey) | UInt32(controlKey)
        XCTAssertEqual(result, expected)
    }

    func testEmptyFlags() {
        let result = HotkeyManager.carbonModifiers(from: [])
        XCTAssertEqual(result, 0)
    }

    func testCapsLockIsIgnored() {
        // capsLock should not contribute to the Carbon modifiers
        let flags: NSEvent.ModifierFlags = [.capsLock, .command]
        let result = HotkeyManager.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(cmdKey), "capsLock flag should be ignored")
    }

    func testFunctionFlagIsIgnored() {
        let flags: NSEvent.ModifierFlags = [.function, .shift]
        let result = HotkeyManager.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(shiftKey), "function flag should be ignored")
    }

    func testNumericPadFlagIsIgnored() {
        let flags: NSEvent.ModifierFlags = [.numericPad, .option]
        let result = HotkeyManager.carbonModifiers(from: flags)
        XCTAssertEqual(result, UInt32(optionKey), "numericPad flag should be ignored")
    }

    func testCommandShiftOption() {
        let flags: NSEvent.ModifierFlags = [.command, .shift, .option]
        let result = HotkeyManager.carbonModifiers(from: flags)
        let expected = UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey)
        XCTAssertEqual(result, expected)
    }
}

// MARK: - displayString(keyCode:carbonModifiers:)

final class HotkeyManagerDisplayStringTests: XCTestCase {

    func testCommandShiftM() {
        // The app's default hotkey: Cmd+Shift+M
        let result = HotkeyManager.displayString(
            keyCode: 0x2E,
            carbonModifiers: UInt32(cmdKey) | UInt32(shiftKey)
        )
        XCTAssertEqual(result, "⇧⌘M")
    }

    func testControlOptionA() {
        let result = HotkeyManager.displayString(
            keyCode: 0x00,
            carbonModifiers: UInt32(controlKey) | UInt32(optionKey)
        )
        XCTAssertEqual(result, "⌃⌥A")
    }

    func testCommandOnly() {
        let result = HotkeyManager.displayString(
            keyCode: 0x08, // C
            carbonModifiers: UInt32(cmdKey)
        )
        XCTAssertEqual(result, "⌘C")
    }

    func testAllModifiersWithF1() {
        let allMods = UInt32(controlKey) | UInt32(optionKey) | UInt32(shiftKey) | UInt32(cmdKey)
        let result = HotkeyManager.displayString(keyCode: 0x7A, carbonModifiers: allMods)
        XCTAssertEqual(result, "⌃⌥⇧⌘F1")
    }

    func testNoModifiers() {
        let result = HotkeyManager.displayString(keyCode: 0x31, carbonModifiers: 0)
        XCTAssertEqual(result, "Space", "No modifier symbols should prefix the key name")
    }

    func testUnknownKeyCodeWithModifiers() {
        let result = HotkeyManager.displayString(
            keyCode: 0xFF,
            carbonModifiers: UInt32(cmdKey)
        )
        XCTAssertEqual(result, "⌘?", "Unknown key codes should show as '?'")
    }

    func testModifierOrderIsControlOptionShiftCommand() {
        // The display order should be ⌃ ⌥ ⇧ ⌘ regardless of the input bit order
        let allMods = UInt32(cmdKey) | UInt32(controlKey) | UInt32(optionKey) | UInt32(shiftKey)
        let result = HotkeyManager.displayString(keyCode: 0x2E, carbonModifiers: allMods)
        XCTAssertTrue(result.hasPrefix("⌃⌥⇧⌘"), "Modifier order should be Control, Option, Shift, Command")
    }

    func testShiftOnlyWithEscape() {
        let result = HotkeyManager.displayString(
            keyCode: 0x35,
            carbonModifiers: UInt32(shiftKey)
        )
        XCTAssertEqual(result, "⇧⎋")
    }

    func testControlCommandWithArrowKey() {
        let result = HotkeyManager.displayString(
            keyCode: 0x7E, // Up arrow
            carbonModifiers: UInt32(controlKey) | UInt32(cmdKey)
        )
        XCTAssertEqual(result, "⌃⌘↑")
    }

    func testOptionShiftWithNumberKey() {
        let result = HotkeyManager.displayString(
            keyCode: 0x12, // 1
            carbonModifiers: UInt32(optionKey) | UInt32(shiftKey)
        )
        XCTAssertEqual(result, "⌥⇧1")
    }

    func testCommandWithReturnKey() {
        let result = HotkeyManager.displayString(
            keyCode: 0x24,
            carbonModifiers: UInt32(cmdKey)
        )
        XCTAssertEqual(result, "⌘↩")
    }

    func testCommandWithTabKey() {
        let result = HotkeyManager.displayString(
            keyCode: 0x30,
            carbonModifiers: UInt32(cmdKey)
        )
        XCTAssertEqual(result, "⌘⇥")
    }

    func testCommandShiftWithBackspace() {
        let result = HotkeyManager.displayString(
            keyCode: 0x33,
            carbonModifiers: UInt32(cmdKey) | UInt32(shiftKey)
        )
        XCTAssertEqual(result, "⇧⌘⌫")
    }
}

// MARK: - hasRequiredModifier(_:)

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

// MARK: - Round-trip: carbonModifiers → displayString

final class HotkeyManagerRoundTripTests: XCTestCase {

    func testCarbonModifiersRoundTripThroughDisplayString() {
        // Convert NSEvent.ModifierFlags → Carbon → displayString and verify
        // that the expected modifier symbols appear.
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let carbon = HotkeyManager.carbonModifiers(from: flags)
        let display = HotkeyManager.displayString(keyCode: 0x2E, carbonModifiers: carbon)
        XCTAssertEqual(display, "⇧⌘M")
    }

    func testControlOptionRoundTrip() {
        let flags: NSEvent.ModifierFlags = [.control, .option]
        let carbon = HotkeyManager.carbonModifiers(from: flags)
        let display = HotkeyManager.displayString(keyCode: 0x00, carbonModifiers: carbon)
        XCTAssertEqual(display, "⌃⌥A")
    }

    func testAllModifiersRoundTrip() {
        let flags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let carbon = HotkeyManager.carbonModifiers(from: flags)
        let display = HotkeyManager.displayString(keyCode: 0x7A, carbonModifiers: carbon)
        XCTAssertEqual(display, "⌃⌥⇧⌘F1")
    }

    func testSingleModifierRoundTrips() {
        // Test each modifier individually round-trips correctly
        let cases: [(NSEvent.ModifierFlags, String, UInt32)] = [
            (.command, "⌘", 0x2E),
            (.shift, "⇧", 0x2E),
            (.option, "⌥", 0x2E),
            (.control, "⌃", 0x2E),
        ]
        for (flags, symbol, keyCode) in cases {
            let carbon = HotkeyManager.carbonModifiers(from: flags)
            let display = HotkeyManager.displayString(keyCode: keyCode, carbonModifiers: carbon)
            XCTAssertTrue(display.contains(symbol), "Display string '\(display)' should contain '\(symbol)'")
            XCTAssertTrue(display.hasSuffix("M"), "Display string '\(display)' should end with 'M'")
        }
    }
}
