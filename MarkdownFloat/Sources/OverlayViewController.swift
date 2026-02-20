import AppKit
import WebKit

class OverlayViewController: NSViewController, NSTextViewDelegate, WKNavigationDelegate {
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var divider: NSBox!
    private var webView: WKWebView!
    private var renderTimer: Timer?
    private var isTemplateLoaded = false
    private var pendingRender = false

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupDivider()
        setupWebView()
        setupConstraints()
        loadMarkdownTemplate()
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = self
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        scrollView.documentView = textView
        view.addSubview(scrollView)
    }

    private func setupDivider() {
        divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(divider)
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.underPageBackgroundColor = .clear
        webView.navigationDelegate = self
        view.addSubview(webView)
    }

    private func setupConstraints() {
        let padding: CGFloat = 24

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35, constant: -padding),

            divider.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),

            webView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.renderMarkdown()
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isTemplateLoaded = true
        if pendingRender {
            pendingRender = false
            renderMarkdown()
        }
    }

    // MARK: - Rendering

    private func renderMarkdown() {
        guard isTemplateLoaded else {
            pendingRender = true
            return
        }
        let text = textView.string
        let base64 = Data(text.utf8).base64EncodedString()
        webView.evaluateJavaScript("renderMarkdown(atob('\(base64)'))", completionHandler: nil)
    }

    // MARK: - Public Methods

    func focusInput() {
        view.window?.makeFirstResponder(textView)
    }

    func prefillFromClipboard() {
        guard textView.string.isEmpty else { return }
        if let clipboardString = NSPasteboard.general.string(forType: .string), !clipboardString.isEmpty {
            textView.string = clipboardString
            renderMarkdown()
        }
    }

    deinit {
        renderTimer?.invalidate()
    }
}
