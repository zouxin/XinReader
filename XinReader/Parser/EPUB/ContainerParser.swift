import Foundation
import ZIPFoundation

/// Parses META-INF/container.xml to find the OPF file path.
///
/// container.xml structure:
/// ```xml
/// <container>
///   <rootfiles>
///     <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
///   </rootfiles>
/// </container>
/// ```
enum ContainerParser {

    /// Parse container.xml and return the OPF file path.
    static func parse(archive: Archive) throws -> String {
        guard let entry = archive["META-INF/container.xml"] else {
            throw EPUBError.containerNotFound
        }

        var xmlData = Data()
        _ = try archive.extract(entry) { data in
            xmlData.append(data)
        }

        let delegate = ContainerXMLDelegate()
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        parser.parse()

        guard let opfPath = delegate.opfPath else {
            throw EPUBError.opfNotFound
        }

        return opfPath
    }
}

// MARK: - XMLParser Delegate

private class ContainerXMLDelegate: NSObject, XMLParserDelegate {
    var opfPath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        if elementName == "rootfile" {
            if let path = attributeDict["full-path"] {
                opfPath = path
            }
        }
    }
}
