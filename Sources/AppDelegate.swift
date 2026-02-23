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
