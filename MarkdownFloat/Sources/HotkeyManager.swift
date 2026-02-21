import Carbon
import AppKit

class HotkeyManager {
    private static let keyCodeDefaultsKey = "hotkeyKeyCode"
    private static let modifiersDefaultsKey = "hotkeyModifiers"

    private static let defaultKeyCode: UInt32 = 0x2E          // kVK_ANSI_M
    private static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onToggle: () -> Void

    private(set) var keyCode: UInt32
    private(set) var modifiers: UInt32

    var displayString: String {
        Self.displayString(keyCode: keyCode, carbonModifiers: modifiers)
    }

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.keyCodeDefaultsKey) != nil {
            self.keyCode = UInt32(defaults.integer(forKey: Self.keyCodeDefaultsKey))
            self.modifiers = UInt32(defaults.integer(forKey: Self.modifiersDefaultsKey))
        } else {
            self.keyCode = Self.defaultKeyCode
            self.modifiers = Self.defaultModifiers
        }

        installHandler()
        registerHotkey()
    }

    // MARK: - Public

    func reregister(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotkey()
        self.keyCode = keyCode
        self.modifiers = modifiers
        UserDefaults.standard.set(Int(keyCode), forKey: Self.keyCodeDefaultsKey)
        UserDefaults.standard.set(Int(modifiers), forKey: Self.modifiersDefaultsKey)
        registerHotkey()
    }

    // MARK: - Private

    private func installHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Safety: passUnretained is used because this object must live for the
        // entire process (owned by AppDelegate). deinit removes the handler before
        // the pointer becomes invalid.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onToggle()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handler
        )
        handlerRef = handler
    }

    private func registerHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D464C54) // "MFLT"
        hotKeyID.id = 1

        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotkeyRef = ref
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    // MARK: - Display Helpers

    static func displayString(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0  { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0   { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0     { parts += "⌘" }
        parts += keyName(for: keyCode)
        return parts
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    static func keyName(for keyCode: UInt32) -> String {
        let table: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
            0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K",
            0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N",
            0x2E: "M", 0x2F: ".",
            0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x24: "↩",
            0x35: "⎋", 0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9",
            0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x32: "`", 0x75: "⌦", 0x73: "↖", 0x77: "↘",
            0x74: "⇞", 0x79: "⇟",
            0x7E: "↑", 0x7D: "↓", 0x7B: "←", 0x7C: "→",
        ]
        return table[keyCode] ?? "?"
    }

    deinit {
        unregisterHotkey()
        if let handler = handlerRef {
            RemoveEventHandler(handler)
        }
    }
}
