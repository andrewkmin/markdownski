import AppKit
import WebKit

private enum SplitMode: Int {
    case horizontal = 0
    case vertical = 1
}

private enum ToolMode: Int {
    case markdown = 0
    case jsonFormat = 1
    case jsonParse = 2
    case jsonStringify = 3
}

private enum JSONToolError: LocalizedError {
    case expectedJSONStringLiteral(String)
    case embeddedJSONInvalid(String)

    var errorDescription: String? {
        switch self {
        case .expectedJSONStringLiteral(let reason):
            let summary = "Input must be a JSON string literal, for example: \"{\\\"name\\\":\\\"Ada\\\"}\""
            return reason.isEmpty ? summary : "\(summary)\n\(reason)"
        case .embeddedJSONInvalid(let reason):
            return "String value does not contain valid JSON.\n\(reason)"
        }
    }
}

private final class EditorTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if flags == [.command] {
            switch key {
            case "a": selectAll(nil); return true
            case "v": paste(nil); return true
            case "c": copy(nil); return true
            case "x": cut(nil); return true
            case "z":
                guard let um = undoManager, um.canUndo else { return super.performKeyEquivalent(with: event) }
                um.undo(); return true
            default: break
            }
        }
        if flags == [.command, .shift], key == "z" {
            guard let um = undoManager, um.canRedo else { return super.performKeyEquivalent(with: event) }
            um.redo(); return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class OverlayViewController: NSViewController, NSTextViewDelegate, WKNavigationDelegate {
    static let minimumPanelWidth: CGFloat = 560

    private static let accentGreen = NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.68, alpha: 0.95)
    private static let copyIconConfig = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .medium)

    private static let autoPasteDefaultsKey = "autoPasteFromClipboardEnabled"
    private static let splitModeDefaultsKey = "previewSplitMode"
    private static let toolModeDefaultsKey = "selectedToolMode"

    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var shortcutChip: NSVisualEffectView!
    private var toolModeControl: NSSegmentedControl!
    private var autoPasteLabel: NSTextField!
    private var autoPasteToggle: NSSwitch!
    private var splitModeControl: NSSegmentedControl!
    private var closeButton: NSButton!

    private var inputCard: NSVisualEffectView!
    private var inputCardTitle: NSTextField!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var placeholderLabel: NSTextField!

    private var previewCard: NSVisualEffectView!
    private var previewCardTitle: NSTextField!
    private var webView: WKWebView!
    private var outputScrollView: NSScrollView!
    private var outputTextView: NSTextView!
    private var copyInputButton: NSButton!
    private var copyOutputButton: NSButton!

    private var splitLayoutConstraints: [NSLayoutConstraint] = []

    private var modeTextStorage: [ToolMode: String] = [:]
    private var currentToolMode: ToolMode = .markdown
    private var copyFeedbackWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]
    private var renderTimer: Timer?
    private var isTemplateLoaded = false
    private var pendingRender = false

    weak var hotkeyManager: HotkeyManager? {
        didSet { updateShortcutLabel() }
    }
    private var shortcutLabel: NSTextField?
    private var isRecordingHotkey = false
    private var hotkeyEventMonitor: Any?
    private var chipRejectionWorkItem: DispatchWorkItem?

    private var isAutoPasteEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.autoPasteDefaultsKey)
    }

    private var selectedSplitMode: SplitMode {
        SplitMode(rawValue: splitModeControl.selectedSegment) ?? .horizontal
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.48).cgColor
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        UserDefaults.standard.register(defaults: [
            Self.autoPasteDefaultsKey: false,
            Self.splitModeDefaultsKey: SplitMode.horizontal.rawValue,
            Self.toolModeDefaultsKey: ToolMode.markdown.rawValue,
        ])

        setupHeader()
        currentToolMode = ToolMode(rawValue: toolModeControl.selectedSegment) ?? .markdown
        setupInputCard()
        setupPreviewCard()
        setupConstraints()
        loadMarkdownTemplate()
        applyToolModeUI()
        updatePlaceholderVisibility()
        processInput()
    }

    // MARK: - Setup

    private func setupHeader() {
        titleLabel = NSTextField(labelWithString: "Markdown")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.96, alpha: 0.98)

        subtitleLabel = NSTextField(labelWithString: "Live preview in a floating workspace")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.80, alpha: 0.84)

        let initialShortcut: String = {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "hotkeyKeyCode") != nil {
                let code = UInt32(defaults.integer(forKey: "hotkeyKeyCode"))
                let mods = UInt32(defaults.integer(forKey: "hotkeyModifiers"))
                return HotkeyManager.displayString(keyCode: code, carbonModifiers: mods)
            }
            return "⌘⇧M"
        }()
        shortcutChip = makeChip(text: initialShortcut)
        shortcutLabel = shortcutChip.subviews.compactMap { $0 as? NSTextField }.first
        shortcutChip.toolTip = "Click to change"

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(shortcutChipClicked(_:)))
        shortcutChip.addGestureRecognizer(clickGesture)

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        shortcutChip.addTrackingArea(trackingArea)

        toolModeControl = makeToolModeControl()
        let savedToolModeRaw = UserDefaults.standard.integer(forKey: Self.toolModeDefaultsKey)
        toolModeControl.selectedSegment = ToolMode(rawValue: savedToolModeRaw)?.rawValue ?? ToolMode.markdown.rawValue

        autoPasteLabel = NSTextField(labelWithString: "Paste from clipboard")
        autoPasteLabel.translatesAutoresizingMaskIntoConstraints = false
        autoPasteLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        autoPasteLabel.textColor = NSColor(calibratedWhite: 0.82, alpha: 0.78)
        autoPasteLabel.lineBreakMode = .byTruncatingTail

        autoPasteToggle = NSSwitch()
        autoPasteToggle.translatesAutoresizingMaskIntoConstraints = false
        autoPasteToggle.controlSize = .small
        autoPasteToggle.state = isAutoPasteEnabled ? .on : .off
        autoPasteToggle.target = self
        autoPasteToggle.action = #selector(autoPasteToggleChanged(_:))

        splitModeControl = makeSplitModeControl()
        let savedSplitModeRaw = UserDefaults.standard.integer(forKey: Self.splitModeDefaultsKey)
        splitModeControl.selectedSegment = SplitMode(rawValue: savedSplitModeRaw)?.rawValue ?? SplitMode.horizontal.rawValue

        closeButton = makeCloseButton()

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(shortcutChip)
        view.addSubview(toolModeControl)
        view.addSubview(autoPasteLabel)
        view.addSubview(autoPasteToggle)
        view.addSubview(splitModeControl)
        view.addSubview(closeButton)
    }

    private func setupInputCard() {
        inputCard = makeCard()
        inputCardTitle = makeCardTitle(text: "Editor")

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        textView = makeEditableTextView()
        textView.delegate = self
        scrollView.documentView = textView

        placeholderLabel = NSTextField(labelWithString: "Write markdown here...")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        placeholderLabel.textColor = NSColor(calibratedWhite: 0.70, alpha: 0.55)

        copyInputButton = makeCopyButton(action: #selector(copyInputPressed(_:)))

        inputCard.addSubview(inputCardTitle)
        inputCard.addSubview(copyInputButton)
        inputCard.addSubview(scrollView)
        inputCard.addSubview(placeholderLabel)
        view.addSubview(inputCard)

        NSLayoutConstraint.activate([
            inputCardTitle.topAnchor.constraint(equalTo: inputCard.topAnchor, constant: 12),
            inputCardTitle.leadingAnchor.constraint(equalTo: inputCard.leadingAnchor, constant: 14),
            inputCardTitle.trailingAnchor.constraint(lessThanOrEqualTo: copyInputButton.leadingAnchor, constant: -8),

            copyInputButton.centerYAnchor.constraint(equalTo: inputCardTitle.centerYAnchor),
            copyInputButton.trailingAnchor.constraint(equalTo: inputCard.trailingAnchor, constant: -12),
            copyInputButton.widthAnchor.constraint(equalToConstant: 26),
            copyInputButton.heightAnchor.constraint(equalToConstant: 22),

            scrollView.topAnchor.constraint(equalTo: inputCardTitle.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: inputCard.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: inputCard.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: inputCard.bottomAnchor, constant: -14),

            placeholderLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 6),
        ])
    }

    private func setupPreviewCard() {
        previewCard = makeCard()
        previewCardTitle = makeCardTitle(text: "Preview")

        let config = WKWebViewConfiguration()
        let clearBgScript = "document.documentElement.style.background='transparent';document.body.style.background='transparent';"
        let userScript = WKUserScript(source: clearBgScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        configureWebViewAppearance()
        webView.navigationDelegate = self

        outputScrollView = NSScrollView()
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false
        outputScrollView.hasVerticalScroller = true
        outputScrollView.scrollerStyle = .overlay
        outputScrollView.drawsBackground = false

        outputTextView = makeReadonlyTextView()
        outputScrollView.documentView = outputTextView

        copyOutputButton = makeCopyButton(action: #selector(copyOutputPressed(_:)))

        previewCard.addSubview(previewCardTitle)
        previewCard.addSubview(copyOutputButton)
        previewCard.addSubview(webView)
        previewCard.addSubview(outputScrollView)
        view.addSubview(previewCard)

        NSLayoutConstraint.activate([
            previewCardTitle.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 12),
            previewCardTitle.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 14),
            previewCardTitle.trailingAnchor.constraint(lessThanOrEqualTo: copyOutputButton.leadingAnchor, constant: -8),

            copyOutputButton.centerYAnchor.constraint(equalTo: previewCardTitle.centerYAnchor),
            copyOutputButton.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -12),
            copyOutputButton.widthAnchor.constraint(equalToConstant: 26),
            copyOutputButton.heightAnchor.constraint(equalToConstant: 22),

            webView.topAnchor.constraint(equalTo: previewCardTitle.bottomAnchor, constant: 10),
            webView.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 8),
            webView.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -8),
            webView.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -8),

            outputScrollView.topAnchor.constraint(equalTo: previewCardTitle.bottomAnchor, constant: 10),
            outputScrollView.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 14),
            outputScrollView.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -14),
            outputScrollView.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -14),
        ])

        DispatchQueue.main.async { [weak self] in
            self?.configureWebViewAppearance()
        }
    }

    private func setupConstraints() {
        let outerPadding: CGFloat = 20

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumPanelWidth),

            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: outerPadding + 2),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: outerPadding + 1),
            closeButton.widthAnchor.constraint(equalToConstant: 15),
            closeButton.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            shortcutChip.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            shortcutChip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -outerPadding),
            shortcutChip.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 14),

            autoPasteToggle.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            autoPasteToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -outerPadding),

            autoPasteLabel.centerYAnchor.constraint(equalTo: autoPasteToggle.centerYAnchor),
            autoPasteLabel.trailingAnchor.constraint(equalTo: autoPasteToggle.leadingAnchor, constant: -8),

            splitModeControl.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            splitModeControl.trailingAnchor.constraint(equalTo: autoPasteLabel.leadingAnchor, constant: -12),
            splitModeControl.leadingAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.trailingAnchor, constant: 16),

            toolModeControl.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            toolModeControl.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            toolModeControl.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -outerPadding),
        ])

        applySplitLayout(mode: selectedSplitMode)
    }

    private func applySplitLayout(mode: SplitMode) {
        NSLayoutConstraint.deactivate(splitLayoutConstraints)
        splitLayoutConstraints.removeAll()

        let outerPadding: CGFloat = 20
        let splitSpacing: CGFloat = 14

        switch mode {
        case .horizontal:
            splitLayoutConstraints = [
                inputCard.topAnchor.constraint(equalTo: toolModeControl.bottomAnchor, constant: 14),
                inputCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: outerPadding),
                inputCard.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -outerPadding),

                previewCard.topAnchor.constraint(equalTo: inputCard.topAnchor),
                previewCard.leadingAnchor.constraint(equalTo: inputCard.trailingAnchor, constant: splitSpacing),
                previewCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -outerPadding),
                previewCard.bottomAnchor.constraint(equalTo: inputCard.bottomAnchor),

                inputCard.widthAnchor.constraint(equalTo: previewCard.widthAnchor),
                inputCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
                previewCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            ]
        case .vertical:
            let inputPreferredHeight = inputCard.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.36)
            inputPreferredHeight.priority = .defaultHigh
            splitLayoutConstraints = [
                inputCard.topAnchor.constraint(equalTo: toolModeControl.bottomAnchor, constant: 14),
                inputCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: outerPadding),
                inputCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -outerPadding),

                previewCard.topAnchor.constraint(equalTo: inputCard.bottomAnchor, constant: splitSpacing),
                previewCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: outerPadding),
                previewCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -outerPadding),
                previewCard.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -outerPadding),

                inputPreferredHeight,
                inputCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 190),
                previewCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            ]
        }

        NSLayoutConstraint.activate(splitLayoutConstraints)
        view.layoutSubtreeIfNeeded()
    }

    private func makeCard() -> NSVisualEffectView {
        let card = NSVisualEffectView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 16
        card.layer?.masksToBounds = true
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.08).cgColor
        card.layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 0.42).cgColor
        return card
    }

    private func makeCardTitle(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.82, alpha: 0.74)
        return label
    }

    private func makeChip(text: String) -> NSVisualEffectView {
        let chip = NSVisualEffectView()
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.material = .hudWindow
        chip.blendingMode = .withinWindow
        chip.state = .active
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 999
        chip.layer?.masksToBounds = true
        chip.layer?.borderWidth = 1
        chip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
        chip.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.04).cgColor

        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.92, alpha: 0.78)

        chip.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: chip.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -9),
        ])

        return chip
    }

    private func makeCloseButton() -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.title = ""
        let closeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        button.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?.withSymbolConfiguration(closeConfig)
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = NSColor(calibratedWhite: 1.0, alpha: 0.70)
        button.toolTip = "Close (Esc)"
        button.target = self
        button.action = #selector(closeButtonPressed(_:))
        button.setButtonType(.momentaryPushIn)
        return button
    }

    private func makeCopyButton(action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.title = ""
        button.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")?.withSymbolConfiguration(Self.copyIconConfig)
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = NSColor(calibratedWhite: 1.0, alpha: 0.45)
        button.toolTip = "Copy to clipboard"
        button.target = self
        button.action = action
        return button
    }

    private func makeToolModeControl() -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: ["Markdown", "Format JSON", "Parse JSON", "Stringify JSON"], trackingMode: .selectOne, target: self, action: #selector(toolModeChanged(_:)))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.controlSize = .small
        control.segmentStyle = .rounded
        control.setWidth(96, forSegment: 0)
        control.setWidth(100, forSegment: 1)
        control.setWidth(96, forSegment: 2)
        control.setWidth(108, forSegment: 3)
        return control
    }

    private func makeSplitModeControl() -> NSSegmentedControl {
        let control: NSSegmentedControl
        if let horizontalImage = makeSplitIcon(systemName: "rectangle.split.2x1"),
           let verticalImage = makeSplitIcon(systemName: "rectangle.split.1x2") {
            control = NSSegmentedControl(images: [horizontalImage, verticalImage], trackingMode: .selectOne, target: self, action: #selector(splitModeChanged(_:)))
        } else {
            control = NSSegmentedControl(labels: ["H", "V"], trackingMode: .selectOne, target: self, action: #selector(splitModeChanged(_:)))
        }

        control.translatesAutoresizingMaskIntoConstraints = false
        control.controlSize = .small
        control.segmentStyle = .rounded
        control.alphaValue = 0.92
        control.setWidth(32, forSegment: 0)
        control.setWidth(32, forSegment: 1)
        control.setToolTip("Horizontal split", forSegment: 0)
        control.setToolTip("Vertical split", forSegment: 1)
        return control
    }

    private func makeSplitIcon(systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        return image.withSymbolConfiguration(config)
    }

    private func makeEditableTextView() -> NSTextView {
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let editor = EditorTextView(frame: .zero, textContainer: textContainer)
        editor.isRichText = false
        editor.backgroundColor = .clear
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 0, height: 10)
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.minSize = NSSize(width: 0, height: 0)
        editor.insertionPointColor = Self.accentGreen
        return editor
    }

    private func makeReadonlyTextView() -> NSTextView {
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let output = EditorTextView(frame: .zero, textContainer: textContainer)
        output.isEditable = false
        output.isSelectable = true
        output.backgroundColor = .clear
        output.drawsBackground = false
        output.textContainerInset = NSSize(width: 0, height: 10)
        output.isAutomaticQuoteSubstitutionEnabled = false
        output.isAutomaticDashSubstitutionEnabled = false
        output.isAutomaticTextReplacementEnabled = false
        output.isHorizontallyResizable = false
        output.isVerticallyResizable = true
        output.autoresizingMask = [.width]
        output.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        output.minSize = NSSize(width: 0, height: 0)
        output.textColor = NSColor(calibratedWhite: 0.90, alpha: 0.95)
        output.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        return output
    }

    private func configureWebViewAppearance() {
        if #available(macOS 13.0, *) {
            webView.underPageBackgroundColor = .clear
        }

        // WKWebView still paints white by default on macOS unless this flag is disabled.
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.enclosingScrollView?.drawsBackground = false
        webView.enclosingScrollView?.backgroundColor = .clear
    }

    // MARK: - Mode UI

    private func applyToolModeUI() {
        switch currentToolMode {
        case .markdown:
            titleLabel.stringValue = "Markdown"
            subtitleLabel.stringValue = "Live preview in a floating workspace"
            inputCardTitle.stringValue = "EDITOR"
            previewCardTitle.stringValue = "PREVIEW"
            webView.isHidden = false
            outputScrollView.isHidden = true
            copyOutputButton.isHidden = true
            applyInputTypography(monospaced: false)

        case .jsonFormat:
            titleLabel.stringValue = "JSON Formatter"
            subtitleLabel.stringValue = "Validate and prettify raw JSON"
            inputCardTitle.stringValue = "RAW JSON"
            previewCardTitle.stringValue = "FORMATTED JSON"
            webView.isHidden = true
            outputScrollView.isHidden = false
            copyOutputButton.isHidden = false
            applyInputTypography(monospaced: true)

        case .jsonParse:
            titleLabel.stringValue = "Parse JSON"
            subtitleLabel.stringValue = "Unwrap a JSON string literal into formatted JSON"
            inputCardTitle.stringValue = "JSON STRING"
            previewCardTitle.stringValue = "PARSED JSON"
            webView.isHidden = true
            outputScrollView.isHidden = false
            copyOutputButton.isHidden = false
            applyInputTypography(monospaced: true)

        case .jsonStringify:
            titleLabel.stringValue = "Stringify JSON"
            subtitleLabel.stringValue = "Wrap a JSON value into an escaped string literal"
            inputCardTitle.stringValue = "JSON OBJECT"
            previewCardTitle.stringValue = "JSON STRING"
            webView.isHidden = true
            outputScrollView.isHidden = false
            copyOutputButton.isHidden = false
            applyInputTypography(monospaced: true)
        }

        placeholderLabel.stringValue = inputPlaceholderText()
        updatePlaceholderVisibility()
    }

    private func applyInputTypography(monospaced: Bool) {

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = monospaced ? 4 : 6

        let font: NSFont
        if monospaced {
            font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        } else {
            font = NSFont.systemFont(ofSize: 15, weight: .regular)
        }

        textView.font = font
        textView.textColor = NSColor(calibratedWhite: 0.92, alpha: 0.96)
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 0.96),
            .paragraphStyle: paragraphStyle,
        ]
    }

    private func inputPlaceholderText() -> String {
        switch currentToolMode {
        case .markdown:
            return "Write markdown here..."
        case .jsonFormat:
            return "Paste raw JSON here..."
        case .jsonParse:
            return "Paste a JSON string literal..."
        case .jsonStringify:
            return "Paste a JSON object/value to stringify..."
        }
    }

    private func outputPlaceholderText() -> String {
        switch currentToolMode {
        case .markdown:
            return ""
        case .jsonFormat:
            return "Formatted JSON appears here."
        case .jsonParse:
            return "Parsed JSON appears here."
        case .jsonStringify:
            return "Stringified JSON appears here."
        }
    }

    // MARK: - Template Loading

    private func loadMarkdownTemplate() {
        guard let templateURL = Bundle.module.url(forResource: "markdown-template", withExtension: "html"),
              let jsURL = Bundle.module.url(forResource: "markdown-it.min", withExtension: "js") else {
            NSLog("Failed to find markdown template or JS resources")
            return
        }

        do {
            var html = try String(contentsOf: templateURL, encoding: .utf8)
            let js = try String(contentsOf: jsURL, encoding: .utf8)
            html = html.replacingOccurrences(of: "MARKDOWN_IT_JS_HERE", with: js)
            webView.loadHTMLString(html, baseURL: nil)
        } catch {
            NSLog("Failed to load markdown template: \(error)")
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()
        scheduleProcessing()
    }

    private func scheduleProcessing() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.processInput()
        }
    }

    // MARK: - Actions

    @objc
    private func autoPasteToggleChanged(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        UserDefaults.standard.set(isEnabled, forKey: Self.autoPasteDefaultsKey)
        if isEnabled {
            prefillFromClipboard()
        }
    }

    @objc
    private func splitModeChanged(_ sender: NSSegmentedControl) {
        let mode = SplitMode(rawValue: sender.selectedSegment) ?? .horizontal
        UserDefaults.standard.set(mode.rawValue, forKey: Self.splitModeDefaultsKey)
        applySplitLayout(mode: mode)
    }

    @objc
    private func toolModeChanged(_ sender: NSSegmentedControl) {
        modeTextStorage[currentToolMode] = textView.string

        let mode = ToolMode(rawValue: sender.selectedSegment) ?? .markdown
        currentToolMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.toolModeDefaultsKey)

        textView.string = modeTextStorage[mode] ?? ""
        textView.undoManager?.removeAllActions()

        applyToolModeUI()
        processInput()
        DispatchQueue.main.async { [weak self] in
            self?.focusInput()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isRecordingHotkey else { return }
        NSCursor.pointingHand.push()
        shortcutChip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.22).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        if !isRecordingHotkey {
            shortcutChip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
        }
    }

    @objc
    private func shortcutChipClicked(_ sender: NSClickGestureRecognizer) {
        guard !isRecordingHotkey else { return }
        NSCursor.pop()
        startRecordingHotkey()
    }

    private func startRecordingHotkey() {
        isRecordingHotkey = true
        shortcutLabel?.stringValue = "Type shortcut…"
        shortcutChip.layer?.borderColor = Self.accentGreen.cgColor
        shortcutChip.layer?.borderWidth = 1.5

        hotkeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event)
            return nil // swallow the event
        }
    }

    private func stopRecordingHotkey() {
        isRecordingHotkey = false
        shortcutChip.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
        shortcutChip.layer?.borderWidth = 1

        if let monitor = hotkeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyEventMonitor = nil
        }
    }

    private func handleRecordedKey(_ event: NSEvent) {
        // Escape cancels
        if event.keyCode == 0x35 {
            stopRecordingHotkey()
            updateShortcutLabel()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasCtrl = flags.contains(.control)

        // Require at least Cmd or Ctrl
        guard hasCmd || hasCtrl else {
            showChipRejection("Requires ⌘ or ⌃")
            return
        }

        let carbonMods = HotkeyManager.carbonModifiers(from: flags)
        let code = UInt32(event.keyCode)

        // Block system-reserved shortcuts (Cmd-only + Q/W/H/Tab)
        if flags == [.command] {
            let reserved: Set<UInt32> = [0x0C, 0x0D, 0x04, 0x30] // Q, W, H, Tab
            if reserved.contains(code) {
                showChipRejection("Reserved by system")
                return
            }
        }

        hotkeyManager?.reregister(keyCode: code, modifiers: carbonMods)
        stopRecordingHotkey()
        updateShortcutLabel()
    }

    private func showChipRejection(_ message: String) {
        chipRejectionWorkItem?.cancel()
        shortcutLabel?.stringValue = message
        let workItem = DispatchWorkItem { [weak self] in
            guard self?.isRecordingHotkey == true else { return }
            self?.shortcutLabel?.stringValue = "Type shortcut…"
        }
        chipRejectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    private func updateShortcutLabel() {
        guard let manager = hotkeyManager else { return }
        shortcutLabel?.stringValue = manager.displayString
    }

    @objc
    private func closeButtonPressed(_ sender: NSButton) {
        if let panel = view.window as? OverlayPanel {
            panel.hide()
            return
        }
        view.window?.orderOut(nil)
    }

    @objc
    private func copyInputPressed(_ sender: NSButton) {
        let text = textView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyFeedback(on: sender)
    }

    @objc
    private func copyOutputPressed(_ sender: NSButton) {
        let text = outputTextView.string
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyFeedback(on: sender)
    }

    private func showCopyFeedback(on button: NSButton) {
        let buttonId = ObjectIdentifier(button)
        copyFeedbackWorkItems[buttonId]?.cancel()

        let docImage = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")?.withSymbolConfiguration(Self.copyIconConfig)
        let defaultTint = NSColor(calibratedWhite: 1.0, alpha: 0.45)

        button.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")?.withSymbolConfiguration(Self.copyIconConfig)
        button.contentTintColor = Self.accentGreen

        let workItem = DispatchWorkItem { [weak button] in
            button?.image = docImage
            button?.contentTintColor = defaultTint
        }
        copyFeedbackWorkItems[buttonId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isTemplateLoaded = true
        if pendingRender {
            pendingRender = false
            processInput()
        }
    }

    // MARK: - Processing

    private func processInput() {
        switch currentToolMode {
        case .markdown:
            renderMarkdown()
        case .jsonFormat:
            renderJSONFormat()
        case .jsonParse:
            renderJSONParse()
        case .jsonStringify:
            renderJSONStringify()
        }
    }

    private func renderMarkdown() {
        guard isTemplateLoaded else {
            pendingRender = true
            return
        }

        let text = textView.string
        let base64 = Data(text.utf8).base64EncodedString()
        webView.evaluateJavaScript("renderMarkdown(atob('\(base64)'))", completionHandler: nil)
    }

    private func renderJSONFormat() {
        let raw = textView.string
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setOutputText(outputPlaceholderText(), kind: .placeholder)
            return
        }

        do {
            let value = try parseJSONValue(from: raw)
            let formatted = try encodeJSON(value: value, pretty: true)
            setOutputText(formatted, kind: .normal)
        } catch {
            setOutputText("Invalid JSON.\n\(error.localizedDescription)", kind: .error)
        }
    }

    private func renderJSONParse() {
        let raw = textView.string
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setOutputText(outputPlaceholderText(), kind: .placeholder)
            return
        }

        do {
            let innerJSONString = try decodeJSONStringLiteral(from: raw)
            let value: Any
            do {
                value = try parseJSONValue(from: innerJSONString)
            } catch {
                throw JSONToolError.embeddedJSONInvalid(error.localizedDescription)
            }
            let formatted = try encodeJSON(value: value, pretty: true)
            setOutputText(formatted, kind: .normal)
        } catch {
            setOutputText("\(error.localizedDescription)", kind: .error)
        }
    }

    private func renderJSONStringify() {
        let raw = textView.string
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setOutputText(outputPlaceholderText(), kind: .placeholder)
            return
        }

        do {
            let value = try parseJSONValue(from: raw)
            let canonicalJSON = try encodeJSON(value: value, pretty: false)
            let encoded = try JSONEncoder().encode(canonicalJSON)
            let stringified = String(decoding: encoded, as: UTF8.self)
            setOutputText(stringified, kind: .normal)
        } catch {
            setOutputText("Invalid JSON value.\n\(error.localizedDescription)", kind: .error)
        }
    }

    private func parseJSONValue(from text: String) throws -> Any {
        let data = Data(text.utf8)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private func encodeJSON(value: Any, pretty: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
        if pretty {
            options.insert(.prettyPrinted)
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    private func decodeJSONStringLiteral(from text: String) throws -> String {
        let data = Data(text.utf8)
        do {
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            throw JSONToolError.expectedJSONStringLiteral(error.localizedDescription)
        }
    }

    private enum OutputTextKind {
        case normal
        case error
        case placeholder
    }

    private func setOutputText(_ text: String, kind: OutputTextKind) {
        let color: NSColor
        switch kind {
        case .normal:
            color = NSColor(calibratedWhite: 0.90, alpha: 0.95)
        case .error:
            color = NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.56, alpha: 0.97)
        case .placeholder:
            color = NSColor(calibratedWhite: 0.72, alpha: 0.58)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ])
        outputTextView.textStorage?.setAttributedString(attributed)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Public Methods

    func cancelHotkeyRecordingIfActive() {
        guard isRecordingHotkey else { return }
        stopRecordingHotkey()
        updateShortcutLabel()
    }

    func focusInput() {
        view.window?.makeFirstResponder(textView)
    }

    func prefillFromClipboard() {
        guard isAutoPasteEnabled else { return }
        guard textView.string.isEmpty else { return }

        if let clipboardString = NSPasteboard.general.string(forType: .string), !clipboardString.isEmpty {
            textView.string = clipboardString
            modeTextStorage[currentToolMode] = clipboardString
            updatePlaceholderVisibility()
            processInput()
        }
    }

    deinit {
        renderTimer?.invalidate()
        if let monitor = hotkeyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
