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
