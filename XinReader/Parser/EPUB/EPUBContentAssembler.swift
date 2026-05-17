import Foundation
import ZIPFoundation

/// Assembles EPUB XHTML spine items into a single HTML string for WKWebView rendering.
///
/// Responsibilities:
/// 1. Read XHTML files in spine order from the ZIP archive
/// 2. Extract <body> content from each XHTML file
/// 3. Wrap each file's content in a div with an anchor ID for TOC navigation
/// 4. Rewrite image paths to use the bookimage:// custom URL scheme
/// 5. Collect all image data from the archive
enum EPUBContentAssembler {

    struct AssembledContent {
        let html: String
        let images: [String: Data]
    }

    /// Assemble all spine items into a single HTML string with extracted images.
    static func assemble(
        archive: Archive,
        opf: OPFDocument,
        basePath: String
    ) throws -> AssembledContent {
        var htmlParts: [String] = []
        var images: [String: Data] = [:]

        // 1. Collect all images from manifest
        for (_, item) in opf.manifest where item.mediaType.hasPrefix("image/") {
            let fullPath = resolvePath(item.href, basePath: basePath)
            if let data = readEntry(archive: archive, path: fullPath) {
                // Store with multiple keys for flexible lookup
                images[item.href] = data
                let filename = (item.href as NSString).lastPathComponent
                images[filename] = data
                // Also store with full path from root
                images[fullPath] = data
            }
        }

        // 2. Process spine items in reading order
        guard !opf.spine.isEmpty else {
            throw EPUBError.spineEmpty
        }

        for spineItem in opf.spine {
            guard let manifestItem = opf.manifest[spineItem.idref] else { continue }

            // Skip non-content items (CSS, NCX, etc.)
            let mediaType = manifestItem.mediaType.lowercased()
            guard mediaType.contains("html") || mediaType.contains("xml") else { continue }

            let fullPath = resolvePath(manifestItem.href, basePath: basePath)

            guard let xhtmlData = readEntry(archive: archive, path: fullPath) else {
                continue
            }

            // Decode with encoding detection
            guard var xhtml = decodeContent(xhtmlData) else {
                continue
            }

            // Extract body content (strip <html>, <head>, <body> wrappers)
            xhtml = extractBodyContent(xhtml)

            // Skip if body is essentially empty
            let trimmed = xhtml.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Rewrite image paths to bookimage:// scheme
            let fileDir = (manifestItem.href as NSString).deletingLastPathComponent
            xhtml = rewriteImagePaths(xhtml, fileDir: fileDir)

            // Wrap in div with multiple anchor IDs for TOC navigation
            // Use both the idref-based ID and the href filename as anchors
            let anchor = "epub_\(spineItem.idref)"
            let hrefFilename = (manifestItem.href as NSString).lastPathComponent
            let hrefNoExt = (hrefFilename as NSString).deletingPathExtension
            htmlParts.append("""
                <div id="\(anchor)" data-href="\(manifestItem.href)" data-filename="\(hrefFilename)" data-basename="\(hrefNoExt)" class="epub-section">
                \(xhtml)
                </div>
                """)
        }

        return AssembledContent(
            html: htmlParts.joined(separator: "\n<hr class=\"section-break\"/>\n"),
            images: images
        )
    }

    // MARK: - Encoding Detection

    /// Decode XHTML data with automatic encoding detection.
    /// Tries: UTF-8, then encoding from XML declaration, then common fallbacks.
    private static func decodeContent(_ data: Data) -> String? {
        // 1. Try UTF-8 first (most common)
        if let str = String(data: data, encoding: .utf8) {
            return str
        }

        // 2. Try to detect encoding from XML declaration: <?xml ... encoding="gbk"?>
        // Read first 200 bytes as ASCII to find the declaration
        let headerBytes = data.prefix(min(200, data.count))
        if let header = String(data: headerBytes, encoding: .ascii) ?? String(data: headerBytes, encoding: .isoLatin1) {
            if let encoding = detectXMLEncoding(header) {
                if let str = String(data: data, encoding: encoding) {
                    return str
                }
            }
        }

        // 3. Common Chinese encodings
        let cfEncodings: [CFStringEncodings] = [
            .GB_18030_2000,    // GB18030 (superset of GBK)
            .GB_2312_80,       // GB2312
            .big5,             // Big5 (Traditional Chinese)
        ]
        for cfEnc in cfEncodings {
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEnc.rawValue))
            let encoding = String.Encoding(rawValue: nsEnc)
            if let str = String(data: data, encoding: encoding) {
                return str
            }
        }

        // 4. Latin1 (never fails - can decode any byte sequence)
        return String(data: data, encoding: .isoLatin1)
    }

    /// Detect encoding from XML declaration string.
    private static func detectXMLEncoding(_ header: String) -> String.Encoding? {
        guard let regex = try? NSRegularExpression(
            pattern: #"encoding\s*=\s*["']([^"']+)["']"#,
            options: .caseInsensitive
        ) else { return nil }

        let nsHeader = header as NSString
        guard let match = regex.firstMatch(in: header, range: NSRange(location: 0, length: nsHeader.length)) else {
            return nil
        }

        let encodingName = nsHeader.substring(with: match.range(at: 1)).lowercased()

        switch encodingName {
        case "utf-8", "utf8":
            return .utf8
        case "gbk", "gb2312", "gb18030":
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
            return String.Encoding(rawValue: nsEnc)
        case "big5":
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))
            return String.Encoding(rawValue: nsEnc)
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        default:
            return nil
        }
    }

    // MARK: - Body Extraction

    /// Extract content between <body> and </body> tags.
    /// If no body tags found, return the entire content (strip XML declaration and head if present).
    private static func extractBodyContent(_ xhtml: String) -> String {
        let nsXHTML = xhtml as NSString

        // Try to find <body...>...</body>
        guard let bodyStartRegex = try? NSRegularExpression(
            pattern: #"<body[^>]*>"#,
            options: [.caseInsensitive]
        ),
        let bodyStartMatch = bodyStartRegex.firstMatch(
            in: xhtml,
            range: NSRange(location: 0, length: nsXHTML.length)
        ) else {
            // No <body> tag found - try stripping XML declaration and doctype, return everything
            return stripXMLPreamble(xhtml)
        }

        let contentStart = bodyStartMatch.range.location + bodyStartMatch.range.length

        // Find </body>
        if let bodyEndRegex = try? NSRegularExpression(
            pattern: #"</body\s*>"#,
            options: .caseInsensitive
        ),
        let bodyEndMatch = bodyEndRegex.firstMatch(
            in: xhtml,
            range: NSRange(location: contentStart, length: nsXHTML.length - contentStart)
        ) {
            let contentEnd = bodyEndMatch.range.location
            return nsXHTML.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
        }

        // No closing body tag, take everything after <body>
        return nsXHTML.substring(from: contentStart)
    }

    /// Strip XML declaration, DOCTYPE, and <html>/<head> sections if no body tag found.
    private static func stripXMLPreamble(_ xhtml: String) -> String {
        var result = xhtml

        // Remove XML declaration
        if let regex = try? NSRegularExpression(pattern: #"<\?xml[^?]*\?>"#, options: .caseInsensitive) {
            let nsStr = result as NSString
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: nsStr.length), withTemplate: "")
        }

        // Remove DOCTYPE
        if let regex = try? NSRegularExpression(pattern: #"<!DOCTYPE[^>]*>"#, options: .caseInsensitive) {
            let nsStr = result as NSString
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: nsStr.length), withTemplate: "")
        }

        // Remove <html...> and </html>
        if let regex = try? NSRegularExpression(pattern: #"</?html[^>]*>"#, options: .caseInsensitive) {
            let nsStr = result as NSString
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: nsStr.length), withTemplate: "")
        }

        // Remove entire <head>...</head> section
        if let regex = try? NSRegularExpression(pattern: #"<head[^>]*>[\s\S]*?</head\s*>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let nsStr = result as NSString
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: nsStr.length), withTemplate: "")
        }

        return result
    }

    // MARK: - Image Path Rewriting

    /// Rewrite relative image paths in XHTML to use bookimage:// scheme.
    private static func rewriteImagePaths(_ html: String, fileDir: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(<img[^>]*\ssrc\s*=\s*")([^"]+)("[^>]*>)"#,
            options: .caseInsensitive
        ) else { return html }

        let nsHTML = html as NSString
        var result = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        // Process in reverse to maintain offsets
        for match in matches.reversed() {
            let srcRange = match.range(at: 2)
            let relativePath = nsHTML.substring(with: srcRange)

            // Skip already-rewritten or absolute URLs
            if relativePath.hasPrefix("bookimage://") || relativePath.hasPrefix("http") {
                continue
            }

            // Resolve relative path
            let resolvedPath = resolveRelativePath(relativePath, from: fileDir)

            // Replace with bookimage:// scheme
            let newSrc = "bookimage://\(resolvedPath)"
            result = (result as NSString).replacingCharacters(in: srcRange, with: newSrc)
        }

        // Also handle single-quoted src and SVG xlink:href
        if let svgRegex = try? NSRegularExpression(
            pattern: #"(<image[^>]*\sxlink:href\s*=\s*")([^"]+)("[^>]*>)"#,
            options: .caseInsensitive
        ) {
            let nsResult = result as NSString
            let svgMatches = svgRegex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            for match in svgMatches.reversed() {
                let srcRange = match.range(at: 2)
                let relativePath = nsResult.substring(with: srcRange)
                if !relativePath.hasPrefix("bookimage://") && !relativePath.hasPrefix("http") {
                    let resolvedPath = resolveRelativePath(relativePath, from: fileDir)
                    result = (result as NSString).replacingCharacters(in: srcRange, with: "bookimage://\(resolvedPath)")
                }
            }
        }

        return result
    }

    /// Resolve a relative path (possibly with ../) against a base directory.
    private static func resolveRelativePath(_ path: String, from baseDir: String) -> String {
        // Already absolute or scheme-based
        if path.hasPrefix("http") || path.hasPrefix("bookimage://") { return path }

        // URL-decode the path
        let decodedPath = path.removingPercentEncoding ?? path

        var components: [String]
        if !baseDir.isEmpty {
            components = baseDir.components(separatedBy: "/").filter { !$0.isEmpty }
        } else {
            components = []
        }

        for part in decodedPath.components(separatedBy: "/") {
            if part == ".." {
                if !components.isEmpty { components.removeLast() }
            } else if part != "." && !part.isEmpty {
                components.append(part)
            }
        }

        return components.joined(separator: "/")
    }

    // MARK: - Helpers

    private static func resolvePath(_ href: String, basePath: String) -> String {
        if basePath.isEmpty { return href }
        return basePath + "/" + href
    }

    /// Read a single entry from the ZIP archive with flexible path matching.
    private static func readEntry(archive: Archive, path: String) -> Data? {
        // Try exact path
        if let data = extractData(archive: archive, path: path) {
            return data
        }

        // Try URL-decoded path
        if let decoded = path.removingPercentEncoding, decoded != path {
            if let data = extractData(archive: archive, path: decoded) {
                return data
            }
        }

        // Try with forward slashes normalized (some ZIPs use backslashes)
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        if normalized != path {
            if let data = extractData(archive: archive, path: normalized) {
                return data
            }
        }

        // Try case-insensitive match by scanning all entries
        let lowercasedPath = path.lowercased()
        for entry in archive {
            if entry.path.lowercased() == lowercasedPath {
                var data = Data()
                _ = try? archive.extract(entry) { chunk in data.append(chunk) }
                return data.isEmpty ? nil : data
            }
        }

        return nil
    }

    /// Extract data from a specific archive path.
    private static func extractData(archive: Archive, path: String) -> Data? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        _ = try? archive.extract(entry) { chunk in data.append(chunk) }
        return data.isEmpty ? nil : data
    }
}
