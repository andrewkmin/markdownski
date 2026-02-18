import AppKit

class OverlayPanel: NSPanel {
    var overlayViewController: OverlayViewController?
    private var isAnimating = false

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panelWidth: CGFloat = 720
        let panelHeight: CGFloat = screen.visibleFrame.height * 0.75
        let originX = screen.frame.midX - panelWidth / 2
        let originY = screen.frame.midY - panelHeight / 2
        let frame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
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

        let visualEffect = NSVisualEffectView(frame: frame)
        visualEffect.material = .sidebar
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        self.contentView = visualEffect

        let viewController = OverlayViewController()
        viewController.view.frame = visualEffect.bounds
        viewController.view.autoresizingMask = [.width, .height]
        visualEffect.addSubview(viewController.view)
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
            self.animator().alphaValue = 1
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
