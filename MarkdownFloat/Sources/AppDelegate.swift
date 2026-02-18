import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let panel = OverlayPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.show()
    }
}
