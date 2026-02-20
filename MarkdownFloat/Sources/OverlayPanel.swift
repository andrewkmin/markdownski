import AppKit

class OverlayPanel: NSPanel {
    var overlayViewController: OverlayViewController?
    private var isAnimating = false
    private let visibleAlpha: CGFloat = 0.95

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panelWidth: CGFloat = 720
        let panelHeight: CGFloat = screen.visibleFrame.height * 0.75
        let originX = screen.frame.midX - panelWidth / 2
        let originY = screen.frame.midY - panelHeight / 2
        let frame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = true
        self.appearance = NSAppearance(named: .darkAqua)
        self.minSize = NSSize(width: 600, height: 420)

        let initialSize = NSSize(width: panelWidth, height: panelHeight)
        self.setContentSize(initialSize)

        let contentBounds = NSRect(origin: .zero, size: initialSize)
        let visualEffectView = NSVisualEffectView(frame: contentBounds)
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 22
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.07).cgColor
        visualEffectView.layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 0.26).cgColor
        visualEffectView.autoresizingMask = [.width, .height]
        self.contentView = visualEffectView

        let viewController = OverlayViewController()
        let overlayView = viewController.view
        overlayView.frame = contentBounds
        overlayView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(overlayView)
        self.overlayViewController = viewController
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    func show() {
        guard !isAnimating else { return }
        isAnimating = true

        overlayViewController?.prefillFromClipboard()

        // Start position: slightly below final position
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
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            self?.overlayViewController?.focusInput()
        }
    }

    func hide() {
        guard !isAnimating else { return }
        isAnimating = true

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.isAnimating = false
        })
    }

    func toggle() {
        if self.isVisible && self.alphaValue > 0 {
            hide()
        } else {
            show()
        }
    }
}
