import SwiftUI
import WebKit

/// NSViewRepresentable wrapper for WKWebView to render book content (MOBI/EPUB).
struct WebContentView: NSViewRepresentable {
    let htmlContent: String
    let images: [String: Data]
    let settings: ReaderSettings
    @Binding var selectedChapter: Chapter?
    var onScrollChange: ((Double, String?) -> Void)?
    var onPageInfo: ((Int, Int, [String: Int]) -> Void)?  // (currentPage, totalPages, chapterPageMap)
    var initialScrollPercent: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Register custom URL scheme for images
        config.setURLSchemeHandler(
            ImageSchemeHandler(images: images),
            forURLScheme: "bookimage"
        )

        // Add message handler for scroll events
        config.userContentController.add(
            context.coordinator,
            name: "scrollHandler"
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView

        // Generate CSS and prepare HTML
        let css = ReaderStyleSheet.generate(from: settings)
        let fullHTML = HTMLCleaner.prepare(html: htmlContent, css: css)

        // Load the HTML
        webView.loadHTMLString(fullHTML, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Check if settings actually changed to avoid redundant JS calls
        let newSettings = settings
        if newSettings != context.coordinator.lastSettings {
            context.coordinator.lastSettings = newSettings
            let css = ReaderStyleSheet.generate(from: newSettings)
            let escapedCSS = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "\n", with: "\\n")
            webView.evaluateJavaScript("updateStyles(`\(escapedCSS)`)")
        }

        // Handle chapter selection changes
        if let chapter = selectedChapter,
           chapter != context.coordinator.lastSelectedChapter {
            context.coordinator.lastSelectedChapter = chapter
            let anchor = chapter.htmlAnchor
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("scrollToAnchorEPUB('\(anchor)')")
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebContentView
        weak var webView: WKWebView?
        var lastSelectedChapter: Chapter?
        var lastSettings: ReaderSettings?
        var hasRestoredScroll = false

        init(_ parent: WebContentView) {
            self.parent = parent
        }

        // WKNavigationDelegate - restore scroll position after content loads
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasRestoredScroll else { return }
            hasRestoredScroll = true

            let percent = parent.initialScrollPercent
            if percent > 0.001 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    webView.evaluateJavaScript("scrollToPercent(\(percent))")
                }
            }
        }

        // WKScriptMessageHandler - receive scroll events from JavaScript
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "scrollHandler",
                  let body = message.body as? [String: Any] else { return }

            let percent = body["percent"] as? Double ?? 0.0
            let anchor = body["anchor"] as? String
            let page = body["currentPage"] as? Int
            let total = body["totalPages"] as? Int

            parent.onScrollChange?(percent, anchor)
            if let p = page, let t = total {
                var chapMap: [String: Int] = [:]
                if let rawMap = body["chapterPages"] as? [String: Any] {
                    for (key, val) in rawMap {
                        if let n = val as? Int {
                            chapMap[key] = n
                        } else if let n = (val as? NSNumber)?.intValue {
                            chapMap[key] = n
                        }
                    }
                }
                parent.onPageInfo?(p, t, chapMap)
            }
        }
    }
}

// MARK: - Image Scheme Handler

/// Custom URL scheme handler to serve book images to WKWebView.
/// Handles URLs like: bookimage://recindex:00001 (MOBI) or bookimage://images/fig1.png (EPUB)
class ImageSchemeHandler: NSObject, WKURLSchemeHandler {
    let images: [String: Data]

    init(images: [String: Data]) {
        self.images = images
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        // Extract the full key from the URL
        let fullURL = url.absoluteString
        let key: String
        if fullURL.hasPrefix("bookimage://") {
            key = String(fullURL.dropFirst("bookimage://".count))
        } else if let host = url.host {
            let path = url.path
            key = path.isEmpty || path == "/" ? host : host + path
        } else {
            key = url.path
        }

        // Try multiple key variations for lookup
        let normalizedKey = normalizeImageKey(key)
        let filename = (key as NSString).lastPathComponent

        let imageData: Data?
        if let data = images[key] {
            imageData = data
        } else if let data = images[normalizedKey] {
            imageData = data
        } else if let data = images[filename] {
            imageData = data
        } else if let data = images[key.removingPercentEncoding ?? key] {
            imageData = data
        } else {
            imageData = nil
        }

        guard let data = imageData else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mimeType = ImageExtractor.mimeType(for: data)
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: nil
        )

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Nothing to cancel
    }

    /// Normalize image key to match the format used in ImageExtractor.
    private func normalizeImageKey(_ key: String) -> String {
        guard key.hasPrefix("recindex:") else { return key }
        let numStr = String(key.dropFirst("recindex:".count))
        guard let num = Int(numStr) else { return key }
        return String(format: "recindex:%05d", num)
    }
}
