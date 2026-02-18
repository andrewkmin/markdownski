import AppKit
import WebKit

class OverlayViewController: NSViewController, NSTextViewDelegate {
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var divider: NSView!
    private var webView: WKWebView!
    private var renderTimer: Timer?

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true

        setupScrollView()
        setupDivider()
        setupWebView()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        textView = NSTextView()
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

        // Line spacing ~6pt for ~1.5 line height at 15px
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        // Allow horizontal resizing with scroll view
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        view.addSubview(scrollView)
    }

    private func setupDivider() {
        divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        view.addSubview(divider)
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.underPageBackgroundColor = .clear
        view.addSubview(webView)
    }

    private func setupConstraints() {
        let padding: CGFloat = 24

        NSLayoutConstraint.activate([
            // ScrollView: 24px padding on top, leading, trailing
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            // ScrollView height = 37% of view height minus padding
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.37, constant: -padding),

            // Divider: 1px height, 24px horizontal padding, below scrollView
            divider.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // WebView: below divider, fills remaining space, no bottom padding
            webView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadMarkdownTemplate()
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

    // MARK: - Rendering

    private func renderMarkdown() {
        let text = textView.string
        let base64 = Data(text.utf8).base64EncodedString()
        webView.evaluateJavaScript("renderMarkdown(atob('\(base64)'))", completionHandler: nil)
    }

    // MARK: - Public Methods

    func focusInput() {
        view.window?.makeFirstResponder(textView)
    }

    func prefillFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            textView.string = clipboardString
            renderMarkdown()
        }
    }
}
