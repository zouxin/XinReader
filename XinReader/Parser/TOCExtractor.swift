import Foundation

/// Extracts the table of contents from MOBI HTML content.
///
/// MOBI files encode TOC in several ways:
/// 1. NCX record (compiled index) — complex binary format, deferred to later phase
/// 2. HTML headings (h1, h2, h3) with anchors — primary strategy
/// 3. <mbp:pagebreak /> markers — Kindle-specific fallback
///
/// This implementation uses Strategy 2 (HTML heading scan) as the primary approach.
struct TOCExtractor {

    /// Extract chapters from HTML content by scanning for heading tags.
    ///
    /// Looks for <h1>, <h2>, <h3> tags, optionally with anchor names/IDs.
    /// Returns a flat list that can be nested by depth.
    static func extractFromHTML(_ html: String) -> [Chapter] {
        var chapters: [Chapter] = []

        // Pattern to match heading tags with optional anchors
        // Handles: <h1><a name="ch1">Title</a></h1>
        //          <h1 id="ch1">Title</h1>
        //          <h2>Title</h2>
        let patterns: [(pattern: String, options: NSRegularExpression.Options)] = [
            // Heading with nested anchor: <h1><a name="...">text</a></h1>
            (#"<(h[1-3])[^>]*>\s*<a[^>]*(?:name|id)\s*=\s*"([^"]*)"[^>]*>(.*?)</a>\s*</\1>"#, [.caseInsensitive, .dotMatchesLineSeparators]),
            // Heading with id attribute: <h1 id="...">text</h1>
            (#"<(h[1-3])\s+[^>]*id\s*=\s*"([^"]*)"[^>]*>(.*?)</\1>"#, [.caseInsensitive, .dotMatchesLineSeparators]),
            // Heading without anchor: <h1>text</h1>
            (#"<(h[1-3])[^>]*>(.*?)</\1>"#, [.caseInsensitive, .dotMatchesLineSeparators]),
        ]

        var foundAnchors: Set<String> = []

        // Try patterns in order of specificity
        for (patternStr, options) in patterns {
            guard let regex = try? NSRegularExpression(pattern: patternStr, options: options) else {
                continue
            }

            let nsHTML = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

            for match in matches {
                let tag = nsHTML.substring(with: match.range(at: 1)).lowercased()
                let depth = headingDepth(tag)

                let anchor: String
                let titleRange: NSRange

                if match.numberOfRanges >= 4 {
                    // Pattern with anchor (has 3 capture groups: tag, anchor, title)
                    anchor = nsHTML.substring(with: match.range(at: 2))
                    titleRange = match.range(at: 3)
                } else if match.numberOfRanges >= 3 {
                    // Pattern without explicit anchor (has 2 capture groups: tag, title)
                    // Generate a synthetic anchor
                    anchor = "chapter_\(chapters.count + 1)"
                    titleRange = match.range(at: 2)
                } else {
                    continue
                }

                // Skip if we already captured this anchor
                if foundAnchors.contains(anchor) { continue }
                foundAnchors.insert(anchor)

                // Clean the title (strip remaining HTML tags)
                let rawTitle = nsHTML.substring(with: titleRange)
                let cleanTitle = stripHTMLTags(rawTitle)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip empty titles
                guard !cleanTitle.isEmpty else { continue }

                // Calculate byte offset for position tracking
                let charOffset = match.range.location

                chapters.append(Chapter(
                    id: UUID(),
                    title: cleanTitle,
                    htmlAnchor: anchor,
                    sourceOffset: charOffset,
                    children: [],
                    depth: depth
                ))
            }

            // If we found chapters with the most specific pattern, use those
            if !chapters.isEmpty { break }
        }

        // If no headings found, try to extract from pagebreak markers
        if chapters.isEmpty {
            chapters = extractFromPageBreaks(html)
        }

        // Nest chapters by depth
        return nestChapters(chapters)
    }

    // MARK: - Fallback: Page Break Extraction

    /// Extract chapters from <mbp:pagebreak /> markers (Kindle-specific).
    private static func extractFromPageBreaks(_ html: String) -> [Chapter] {
        var chapters: [Chapter] = []

        let pattern = #"<mbp:pagebreak\s*/>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return chapters
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for (index, match) in matches.enumerated() {
            let charOffset = match.range.location

            // Try to find text after the pagebreak for a title
            let afterRange = NSRange(location: charOffset + match.range.length,
                                     length: min(200, nsHTML.length - charOffset - match.range.length))
            let afterText = nsHTML.substring(with: afterRange)
            let title = extractFirstTextContent(afterText) ?? "Chapter \(index + 1)"

            chapters.append(Chapter(
                id: UUID(),
                title: title,
                htmlAnchor: "pagebreak_\(index)",
                sourceOffset: charOffset,
                children: [],
                depth: 0
            ))
        }

        return chapters
    }

    // MARK: - Helpers

    private static func headingDepth(_ tag: String) -> Int {
        switch tag {
        case "h1": return 0
        case "h2": return 1
        case "h3": return 2
        default: return 0
        }
    }

    /// Strip all HTML tags from a string
    private static func stripHTMLTags(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return html
        }
        let nsHTML = html as NSString
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length),
            withTemplate: ""
        )
    }

    /// Extract the first meaningful text content from an HTML fragment
    private static func extractFirstTextContent(_ html: String) -> String? {
        let stripped = stripHTMLTags(html)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Take first line or first 50 chars
        let firstLine = stripped.prefix(while: { $0 != "\n" && $0 != "\r" })
        let trimmed = String(firstLine.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Convert a flat list of chapters with depth into a nested tree.
    private static func nestChapters(_ flat: [Chapter]) -> [Chapter] {
        guard !flat.isEmpty else { return [] }

        var result: [Chapter] = []
        var stack: [(depth: Int, index: Int)] = [] // Track parent positions

        for chapter in flat {
            if chapter.depth == 0 {
                // Top-level chapter
                result.append(chapter)
                stack = [(depth: 0, index: result.count - 1)]
            } else {
                // Find appropriate parent
                while let last = stack.last, last.depth >= chapter.depth {
                    stack.removeLast()
                }

                if stack.isEmpty {
                    // No parent found, add as top-level
                    result.append(chapter)
                    stack.append((depth: chapter.depth, index: result.count - 1))
                } else {
                    // Add as child of the last item in stack
                    let parentIndex = stack.last!.index
                    if stack.count == 1 {
                        result[parentIndex].children.append(chapter)
                    } else {
                        // Nested deeper - for simplicity, add to top-level parent's children
                        result[parentIndex].children.append(chapter)
                    }
                    stack.append((depth: chapter.depth, index: parentIndex))
                }
            }
        }

        return result
    }
}
