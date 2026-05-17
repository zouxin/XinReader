import Foundation
import ZIPFoundation

/// Parses the EPUB table of contents from NCX (EPUB2) or nav.xhtml (EPUB3).
enum EPUBTOCParser {

    /// Extract chapters from the EPUB TOC.
    /// Tries EPUB3 nav document first, then falls back to NCX.
    static func parse(archive: Archive, opf: OPFDocument, basePath: String) throws -> [Chapter] {
        // Strategy 1: EPUB3 — look for manifest item with properties="nav"
        if let navItem = opf.manifest.values.first(where: { $0.properties?.contains("nav") == true }) {
            let navPath = resolvePath(navItem.href, basePath: basePath)
            if let chapters = try? parseNavDocument(archive: archive, path: navPath) {
                if !chapters.isEmpty { return chapters }
            }
        }

        // Strategy 2: EPUB2 — NCX file referenced by spine toc attribute
        if let tocID = opf.tocID, let tocItem = opf.manifest[tocID] {
            let ncxPath = resolvePath(tocItem.href, basePath: basePath)
            if let chapters = try? parseNCX(archive: archive, path: ncxPath) {
                if !chapters.isEmpty { return chapters }
            }
        }

        // Strategy 3: Generate from spine items
        return generateFromSpine(opf: opf)
    }

    // MARK: - EPUB3 Navigation Document

    /// Parse nav.xhtml: <nav epub:type="toc"><ol><li><a href="...">Title</a></li></ol></nav>
    private static func parseNavDocument(archive: Archive, path: String) throws -> [Chapter] {
        guard let entry = archive[path] else { return [] }

        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }

        guard let html = String(data: data, encoding: .utf8) else { return [] }

        // Use regex to extract <a href="...">title</a> from ordered list items
        return parseNavOL(html: html, depth: 0)
    }

    /// Recursively parse <ol><li><a>... structures in nav HTML.
    private static func parseNavOL(html: String, depth: Int) -> [Chapter] {
        var chapters: [Chapter] = []

        // Match <li> elements containing <a href="...">title</a>
        let pattern = #"<li[^>]*>\s*<a\s+[^>]*href\s*=\s*"([^"]*)"[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return chapters
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            let href = nsHTML.substring(with: match.range(at: 1))
            let rawTitle = nsHTML.substring(with: match.range(at: 2))
            let title = stripHTML(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !title.isEmpty else { continue }

            chapters.append(Chapter(
                title: title,
                htmlAnchor: href,
                depth: depth
            ))
        }

        return chapters
    }

    // MARK: - EPUB2 NCX

    /// Parse toc.ncx: <navMap><navPoint><navLabel><text>Title</text></navLabel><content src="..."/></navPoint></navMap>
    private static func parseNCX(archive: Archive, path: String) throws -> [Chapter] {
        guard let entry = archive[path] else { return [] }

        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }

        let delegate = NCXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        return delegate.chapters
    }

    // MARK: - Fallback: Generate from Spine

    /// If no TOC is found, generate chapter entries from spine items.
    private static func generateFromSpine(opf: OPFDocument) -> [Chapter] {
        return opf.spine.enumerated().compactMap { index, item in
            guard let manifest = opf.manifest[item.idref] else { return nil }
            return Chapter(
                title: "Chapter \(index + 1)",
                htmlAnchor: manifest.href,
                depth: 0
            )
        }
    }

    // MARK: - Helpers

    private static func resolvePath(_ href: String, basePath: String) -> String {
        if basePath.isEmpty { return href }
        return basePath + "/" + href
    }

    private static func stripHTML(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else { return html }
        let nsHTML = html as NSString
        return regex.stringByReplacingMatches(in: html, range: NSRange(location: 0, length: nsHTML.length), withTemplate: "")
    }
}

// MARK: - NCX XMLParser Delegate

private class NCXParserDelegate: NSObject, XMLParserDelegate {
    var chapters: [Chapter] = []

    private var currentText = ""
    private var inNavPoint = false
    private var inNavLabel = false
    private var inText = false
    private var navPointDepth = 0
    private var currentTitle = ""
    private var currentSrc = ""
    private var depthStack: [Int] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attrs: [String: String]
    ) {
        switch elementName {
        case "navPoint":
            inNavPoint = true
            navPointDepth = depthStack.count
            depthStack.append(navPointDepth)
            currentTitle = ""
            currentSrc = ""

        case "navLabel":
            inNavLabel = true

        case "text":
            if inNavLabel {
                inText = true
                currentText = ""
            }

        case "content":
            if inNavPoint, let src = attrs["src"] {
                currentSrc = src
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "text":
            if inText {
                currentTitle = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                inText = false
            }

        case "navLabel":
            inNavLabel = false

        case "navPoint":
            if !currentTitle.isEmpty {
                chapters.append(Chapter(
                    title: currentTitle,
                    htmlAnchor: currentSrc,
                    depth: navPointDepth
                ))
            }
            depthStack.removeLast()
            inNavPoint = !depthStack.isEmpty

        default:
            break
        }
    }
}
