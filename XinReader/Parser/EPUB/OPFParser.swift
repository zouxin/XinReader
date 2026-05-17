import Foundation
import ZIPFoundation

/// Parses the OPF (Open Packaging Format) file from an EPUB archive.
///
/// The OPF file contains:
/// - Metadata: title, author, publisher, cover image ID
/// - Manifest: all files in the EPUB with IDs, hrefs, and media types
/// - Spine: reading order (ordered list of manifest item IDs)
enum OPFParser {

    /// Parse the OPF file and return an OPFDocument.
    static func parse(archive: Archive, opfPath: String) throws -> OPFDocument {
        guard let entry = archive[opfPath] else {
            throw EPUBError.opfNotFound
        }

        var xmlData = Data()
        _ = try archive.extract(entry) { data in
            xmlData.append(data)
        }

        let delegate = OPFXMLDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.parse()

        guard !delegate.manifest.isEmpty else {
            throw EPUBError.opfParseFailed("Empty manifest")
        }

        return OPFDocument(
            metadata: delegate.metadata,
            manifest: delegate.manifest,
            spine: delegate.spine,
            tocID: delegate.tocID
        )
    }
}

// MARK: - OPF Data Structures

struct OPFDocument {
    var metadata: OPFMetadata
    var manifest: [String: ManifestItem]  // id → item
    var spine: [SpineItem]
    var tocID: String?                     // NCX manifest ID from <spine toc="...">

    struct ManifestItem {
        let id: String
        let href: String
        let mediaType: String
        var properties: String?
    }

    struct SpineItem {
        let idref: String
    }
}

struct OPFMetadata {
    var title: String?
    var author: String?
    var publisher: String?
    var coverImageID: String?
}

// MARK: - XMLParser Delegate

private class OPFXMLDelegate: NSObject, XMLParserDelegate {
    var metadata = OPFMetadata()
    var manifest: [String: OPFDocument.ManifestItem] = [:]
    var spine: [OPFDocument.SpineItem] = []
    var tocID: String?

    private var currentElement = ""
    private var currentText = ""
    private var elementStack: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attrs: [String: String]
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        elementStack.append(localName)
        currentElement = localName
        currentText = ""

        switch localName {
        case "item":
            // Manifest item
            if let id = attrs["id"], let href = attrs["href"], let mediaType = attrs["media-type"] {
                let properties = attrs["properties"]
                manifest[id] = OPFDocument.ManifestItem(
                    id: id,
                    href: href,
                    mediaType: mediaType,
                    properties: properties
                )
            }

        case "itemref":
            // Spine item
            if let idref = attrs["idref"] {
                spine.append(OPFDocument.SpineItem(idref: idref))
            }

        case "spine":
            // Get the NCX toc reference
            tocID = attrs["toc"]

        case "meta":
            // Cover image: <meta name="cover" content="cover-image-id"/>
            if attrs["name"] == "cover", let content = attrs["content"] {
                metadata.coverImageID = content
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if we're inside <metadata>
        let inMetadata = elementStack.contains("metadata")

        if inMetadata && !trimmed.isEmpty {
            switch localName {
            case "title":
                metadata.title = trimmed
            case "creator":
                metadata.author = trimmed
            case "publisher":
                metadata.publisher = trimmed
            default:
                break
            }
        }

        elementStack.removeLast()
        currentText = ""
    }
}
