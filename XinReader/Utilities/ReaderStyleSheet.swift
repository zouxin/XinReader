import Foundation

/// Generates dynamic CSS for the reader based on current settings.
struct ReaderStyleSheet {

    /// Generate a complete CSS stylesheet from reader settings.
    static func generate(from settings: ReaderSettings) -> String {
        let theme = settings.theme

        return """
        * {
            box-sizing: border-box;
        }

        :root {
            --bg-color: \(theme.backgroundColor);
            --text-color: \(theme.textColor);
            --link-color: \(theme.linkColor);
        }

        html, body {
            width: 100%;
            height: 100%;
            margin: 0;
            padding: 0;
            overflow: hidden;
            background-color: var(--bg-color);
        }

        #book-container {
            position: absolute;
            top: 0; left: 0; right: 0; bottom: 2em;
            overflow: hidden;
            padding: 2em 3em;
        }

        #book-content {
            height: 100%;
            overflow: hidden;

            font-family: '\(settings.fontFamily)', 'PingFang SC', -apple-system, serif;
            font-size: \(Int(settings.fontSize))px;
            line-height: \(settings.lineSpacing);
            color: var(--text-color);
            word-wrap: break-word;
            overflow-wrap: break-word;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;

            column-count: 2;
            column-gap: 4em;
            column-rule: 1px solid rgba(128, 128, 128, 0.15);
            column-fill: auto;
        }

        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            color: var(--text-color);
            margin-top: 1.2em;
            margin-bottom: 0.4em;
            line-height: 1.3;
            -webkit-column-break-after: avoid;
            break-after: avoid;
        }
        h1 { font-size: 1.6em; }
        h2 { font-size: 1.4em; }
        h3 { font-size: 1.2em; }

        p {
            margin: 0.6em 0;
            text-align: justify;
            orphans: 2;
            widows: 2;
        }

        a { color: var(--link-color); text-decoration: none; }
        a:hover { text-decoration: underline; }

        img {
            max-width: 100%;
            max-height: 80vh;
            height: auto;
            display: block;
            margin: 1em auto;
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
        }
        td, th {
            border: 1px solid var(--text-color);
            padding: 0.5em;
            opacity: 0.7;
        }

        blockquote {
            border-left: 3px solid var(--link-color);
            margin: 1em 0;
            padding: 0.5em 1em;
            opacity: 0.9;
        }

        pre, code {
            font-family: 'Menlo', 'Monaco', monospace;
            font-size: 0.9em;
            background-color: rgba(128, 128, 128, 0.1);
            border-radius: 3px;
            padding: 0.2em 0.4em;
        }
        pre {
            padding: 1em;
            overflow-x: auto;
            -webkit-column-break-inside: avoid;
            break-inside: avoid;
        }

        hr {
            border: none;
            border-top: 1px solid var(--text-color);
            opacity: 0.3;
            margin: 1.5em 0;
        }
        hr.section-break {
            border: none;
            margin: 1em 0;
        }
        .epub-section {
            break-inside: auto;
        }

        #page-indicator {
            position: fixed;
            bottom: 0.4em;
            left: 50%;
            transform: translateX(-50%);
            font-size: 12px;
            color: var(--text-color);
            opacity: 0.45;
            pointer-events: none;
            z-index: 1000;
            font-family: -apple-system, sans-serif;
        }

        ::selection {
            background-color: \(theme.linkColor);
            color: \(theme.backgroundColor);
        }
        """
    }
}
