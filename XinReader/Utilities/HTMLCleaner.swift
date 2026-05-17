import Foundation

/// Cleans and prepares HTML content for rendering in WKWebView.
///
/// Responsibilities:
/// 1. Rewrite image references from recindex to custom URL scheme
/// 2. Inject anchor IDs at headings for TOC navigation
/// 3. Clean up malformed HTML common in MOBI files
/// 4. Wrap content in the reader template
struct HTMLCleaner {

    /// Process raw HTML for WKWebView rendering.
    ///
    /// - Parameters:
    ///   - html: Raw HTML from content assembly
    ///   - css: Dynamic CSS string from ReaderStyleSheet
    /// - Returns: Complete HTML document ready for WKWebView
    static func prepare(html: String, css: String) -> String {
        var processed = html

        // 1. Rewrite image tags: <img recindex="00001"> → <img src="bookimage://recindex:00001">
        processed = rewriteImageTags(processed)

        // 2. Inject anchor IDs at headings (for TOC navigation)
        processed = injectHeadingAnchors(processed)

        // 3. Fix common HTML issues in MOBI files
        processed = fixMalformedHTML(processed)

        // 4. Wrap in template
        return wrapInTemplate(content: processed, css: css)
    }

    // MARK: - Image Tag Rewriting

    /// Rewrite MOBI-specific image references to use custom URL scheme.
    /// Handles various formats:
    /// - <img recindex="00001">
    /// - <img recindex="00001" />
    /// - <img src="kindle:embed:00001">
    private static func rewriteImageTags(_ html: String) -> String {
        var result = html

        // Pattern: recindex="NNNNN" or recindex='NNNNN'
        if let regex = try? NSRegularExpression(
            pattern: #"<img([^>]*?)recindex\s*=\s*["'](\d+)["']([^>]*?)\s*/?>"#,
            options: .caseInsensitive
        ) {
            let nsHTML = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: nsHTML.length),
                withTemplate: #"<img$1src="bookimage://recindex:$2"$3>"#
            )
        }

        // Pattern: src="kindle:embed:NNNNN"
        if let regex = try? NSRegularExpression(
            pattern: #"src\s*=\s*["']kindle:embed:(\d+)["']"#,
            options: .caseInsensitive
        ) {
            let nsHTML = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: nsHTML.length),
                withTemplate: #"src="bookimage://recindex:$1""#
            )
        }

        return result
    }

    // MARK: - Heading Anchor Injection

    /// Add id attributes to headings that don't already have anchors.
    /// This ensures TOC navigation can scroll to any heading.
    private static func injectHeadingAnchors(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<(h[1-3])(\s[^>]*)?>(?!.*?<a[^>]*name=)"#,
            options: .caseInsensitive
        ) else { return html }

        var result = html
        let nsHTML = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))

        // Process in reverse order to maintain offsets
        var chapterIndex = matches.count
        for match in matches.reversed() {
            let tag = nsHTML.substring(with: match.range(at: 1))
            let anchorID = "chapter_\(chapterIndex)"
            chapterIndex -= 1

            let replacement = "<\(tag) id=\"\(anchorID)\""
            if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                // Has existing attributes - add id
                let existingAttrs = nsHTML.substring(with: match.range(at: 2))
                if !existingAttrs.contains("id=") {
                    let fullReplacement = "<\(tag) id=\"\(anchorID)\"\(existingAttrs)>"
                    result = (result as NSString).replacingCharacters(in: match.range, with: fullReplacement)
                }
            } else {
                // No attributes - add id
                let fullReplacement = "\(replacement)>"
                result = (result as NSString).replacingCharacters(in: match.range, with: fullReplacement)
            }
        }

        return result
    }

    // MARK: - HTML Fixes

    /// Fix common malformed HTML issues in MOBI files.
    private static func fixMalformedHTML(_ html: String) -> String {
        var result = html

        // Fix unclosed <br> tags (common in older MOBI)
        result = result.replacingOccurrences(of: "<br>", with: "<br/>")

        // Fix unclosed <hr> tags
        result = result.replacingOccurrences(of: "<hr>", with: "<hr/>")

        // Remove Kindle-specific XML namespace tags
        if let regex = try? NSRegularExpression(
            pattern: #"</?mbp:[^>]*>"#,
            options: .caseInsensitive
        ) {
            let nsHTML = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: nsHTML.length),
                withTemplate: ""
            )
        }

        // Remove any <script> tags from content to avoid breaking our template
        if let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*>[\s\S]*?</script>"#,
            options: .caseInsensitive
        ) {
            let nsHTML = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: nsHTML.length),
                withTemplate: ""
            )
        }

        return result
    }

    // MARK: - Template Wrapping

    /// Wrap content in the reader HTML template with paginated two-page layout.
    /// Uses scrollLeft for horizontal pagination — never touches transform.
    private static func wrapInTemplate(content: String, css: String) -> String {
        // The JS is defined as a raw string to avoid any Swift interpolation issues.
        // It uses scrollLeft on #book-content to paginate horizontally.
        let js = #"""
        (function() {
            var currentPage = 0;
            var totalPages = 1;
            var stepWidth = 0;
            var cachedChapterPages = {};

            function C() { return document.getElementById('book-content'); }

            // ─── pagination math ────────────────────────────────
            // CSS columns layout: content flows into columns horizontally.
            // clientWidth = visible area (2 columns + 1 gap between them).
            // Between each "screen" there is an additional gap.
            // So one page-turn step = clientWidth + columnGap.
            function recalc() {
                var c = C(); if (!c) return;
                var cw = c.clientWidth;
                if (cw <= 0) return;

                var style = window.getComputedStyle(c);
                var gap = parseFloat(style.columnGap) || 0;

                stepWidth = cw + gap;

                var sw = c.scrollWidth;
                totalPages = Math.max(1, Math.ceil(sw / stepWidth));
                if (currentPage >= totalPages) currentPage = totalPages - 1;
                if (currentPage < 0) currentPage = 0;
                showIndicator();
                calcChapterPages();
            }

            // Calculate which page each chapter/section lives on.
            // Called once per recalc, result cached for report().
            function calcChapterPages() {
                cachedChapterPages = {};
                var c = C();
                if (!c || stepWidth <= 0) return;
                var saved = c.scrollLeft;
                c.scrollLeft = 0;
                void c.scrollWidth;
                // Gather all identifiable section/heading elements
                var els = c.querySelectorAll('.epub-section[id], .epub-section[data-href], h1[id], h2[id], h3[id]');
                for (var i = 0; i < els.length; i++) {
                    var el = els[i];
                    var id = el.id || '';
                    var href = el.getAttribute('data-href') || '';
                    var fname = el.getAttribute('data-filename') || '';
                    var bname = el.getAttribute('data-basename') || '';
                    var left = el.offsetLeft;
                    var p = el.offsetParent;
                    while (p && p !== c && p !== document.body) { left += p.offsetLeft; p = p.offsetParent; }
                    var pg = Math.floor(left / stepWidth);
                    if (id) cachedChapterPages[id] = pg;
                    if (href) cachedChapterPages[href] = pg;
                    if (fname) cachedChapterPages[fname] = pg;
                    if (bname) cachedChapterPages[bname] = pg;
                }
                c.scrollLeft = saved;
            }

            function goTo(n) {
                var c = C(); if (!c) return;
                recalc();
                if (n < 0) n = 0;
                if (n >= totalPages) n = totalPages - 1;
                currentPage = n;
                c.scrollLeft = currentPage * stepWidth;
                showIndicator();
                report();
            }

            function next() { goTo(currentPage + 1); }
            function prev() { goTo(currentPage - 1); }

            // ─── style hot-reload ───────────────────────────────
            // called from Swift via evaluateJavaScript
            window.updateStyles = function(css) {
                document.getElementById('dynamic-styles').textContent = css;
                setTimeout(function() {
                    var pct = (totalPages > 1) ? currentPage / (totalPages - 1) : 0;
                    recalc();
                    goTo(Math.round(pct * Math.max(0, totalPages - 1)));
                }, 80);
            };

            // ─── progress ───────────────────────────────────────
            window.scrollToPercent = function(pct) {
                recalc();
                goTo(Math.round(pct * Math.max(0, totalPages - 1)));
            };
            window.getScrollPercent = function() {
                return (totalPages <= 1) ? 0 : currentPage / (totalPages - 1);
            };

            // ─── chapter navigation ─────────────────────────────
            // Finds which page an element lives on using its offsetLeft.
            // scrollLeft is 0 while measuring because we haven't moved yet
            // OR we temporarily reset it, measure, and restore.
            function pageOfElement(el) {
                if (!el) return -1;
                var c = C(); if (!c) return -1;
                recalc();
                if (stepWidth <= 0) return 0;

                // save current scroll, reset to 0 so offsetLeft is absolute
                var saved = c.scrollLeft;
                c.scrollLeft = 0;
                // force reflow so measurement is fresh
                void c.scrollWidth;

                var left = el.offsetLeft;
                // walk up to the container to accumulate offsets
                var p = el.offsetParent;
                while (p && p !== c && p !== document.body) {
                    left += p.offsetLeft;
                    p = p.offsetParent;
                }

                c.scrollLeft = saved;          // restore immediately
                return Math.floor(left / stepWidth);
            }

            window.scrollToAnchor = function(id) {
                var el = document.getElementById(id) || document.querySelector('[name="' + id + '"]');
                if (el) goTo(pageOfElement(el));
            };

            window.scrollToAnchorEPUB = function(href) {
                var el = findEPUBElement(href);
                if (el) goTo(pageOfElement(el));
            };

            function findEPUBElement(href) {
                // 1. direct id
                var el = document.getElementById(href);
                if (el) return el;

                // split fragment
                var frag = '', path = href, h = href.indexOf('#');
                if (h >= 0) { frag = href.substring(h+1); path = href.substring(0,h); }

                // 2. data-href / data-filename / data-basename
                el = document.querySelector('[data-href="' + path + '"]');
                if (!el) {
                    var parts = path.split('/');
                    el = document.querySelector('[data-filename="' + parts[parts.length-1] + '"]');
                }
                if (!el) {
                    var bn = path.split('/').pop().replace(/\.[^.]*$/,'');
                    el = document.querySelector('[data-basename="' + bn + '"]');
                }
                // if we found the section and there's a fragment, drill in
                if (el && frag) {
                    var inner = el.querySelector('#'+frag) || el.querySelector('[name="'+frag+'"]');
                    if (inner) return inner;
                }
                if (el) return el;

                // 3. global fragment
                if (frag) {
                    el = document.getElementById(frag) || document.querySelector('[name="'+frag+'"]');
                    if (el) return el;
                }

                // 4. fuzzy scan
                var secs = document.querySelectorAll('.epub-section');
                var sn = path.split('/').pop().replace(/\.[^.]*$/,'').toLowerCase();
                for (var i=0;i<secs.length;i++) {
                    var b=(secs[i].getAttribute('data-basename')||'').toLowerCase();
                    var d=(secs[i].getAttribute('data-href')||'').toLowerCase();
                    if (b===sn || d.indexOf(sn)>=0) return secs[i];
                }
                return null;
            }

            // ─── current anchor (for sidebar highlight) ─────────
            window.getCurrentAnchor = function() {
                var c = C(); if (!c) return '';
                var sl = c.scrollLeft;
                var best = '';
                var nodes = c.querySelectorAll('.epub-section[id], h1[id], h2[id], h3[id]');
                for (var i=0;i<nodes.length;i++) {
                    if (nodes[i].offsetLeft <= sl + stepWidth) best = nodes[i].id || '';
                }
                return best;
            };

            // ─── page indicator ─────────────────────────────────
            function showIndicator() {
                var ind = document.getElementById('page-indicator');
                if (ind) ind.textContent = (currentPage+1) + ' / ' + totalPages;
            }
            function report() {
                try {
                    window.webkit.messageHandlers.scrollHandler.postMessage({
                        percent: window.getScrollPercent(),
                        anchor: window.getCurrentAnchor(),
                        currentPage: currentPage,
                        totalPages: totalPages,
                        chapterPages: cachedChapterPages
                    });
                } catch(e){}
            }

            // ─── input handling ─────────────────────────────────
            // Wheel: single event = single page turn, with cooldown to avoid rapid-fire
            var wheelCooldown = false;
            document.addEventListener('wheel', function(e) {
                e.preventDefault();
                if (wheelCooldown) return;
                if (e.deltaY > 2) { next(); wheelCooldown = true; }
                else if (e.deltaY < -2) { prev(); wheelCooldown = true; }
                if (wheelCooldown) setTimeout(function(){ wheelCooldown = false; }, 250);
            }, {passive:false});

            document.addEventListener('keydown', function(e) {
                var k = e.key;
                if (k==='ArrowRight'||k==='ArrowDown'||k===' '||k==='PageDown')  { e.preventDefault(); next(); }
                if (k==='ArrowLeft'||k==='ArrowUp'||k==='Backspace'||k==='PageUp') { e.preventDefault(); prev(); }
                if (k==='Home') { e.preventDefault(); goTo(0); }
                if (k==='End')  { e.preventDefault(); goTo(totalPages-1); }
            });

            window.addEventListener('resize', function() {
                var pct = window.getScrollPercent();
                recalc();
                goTo(Math.round(pct * Math.max(0, totalPages-1)));
            });

            // ─── init ───────────────────────────────────────────
            // Use a short poll to wait for the container to be laid out.
            var initAttempts = 0;
            function tryInit() {
                var c = C();
                if (c && c.clientWidth > 0 && c.scrollWidth > 0) {
                    recalc();
                    report();
                } else if (initAttempts < 20) {
                    initAttempts++;
                    setTimeout(tryInit, 100);
                }
            }
            if (document.readyState === 'complete') tryInit();
            else window.addEventListener('load', function(){ setTimeout(tryInit, 50); });
        })();
        """#

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style id="dynamic-styles">
            \(css)
            </style>
        </head>
        <body>
            <div id="book-container">
                <div id="book-content">
                \(content)
                </div>
            </div>
            <div id="page-indicator"></div>
            <script>\(js)</script>
        </body>
        </html>
        """
    }
}

