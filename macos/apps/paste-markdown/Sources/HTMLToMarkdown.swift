import Foundation

enum HTMLToMarkdown {
    static func convert(_ html: String) -> String {
        guard let doc = try? XMLDocument(xmlString: html, options: [.documentTidyHTML]),
              let root = doc.rootElement(),
              let body = findElement("body", in: root)
        else {
            return stripTags(html)
        }

        let raw = processElement(body, listDepth: 0)
        return normalize(raw)
    }

    // MARK: - Tree Traversal

    private static func findElement(_ name: String, in element: XMLElement) -> XMLElement? {
        if element.name?.lowercased() == name { return element }
        for child in element.children ?? [] {
            if let el = child as? XMLElement,
               let found = findElement(name, in: el) {
                return found
            }
        }
        return nil
    }

    private static func processChildren(of element: XMLElement, listDepth: Int) -> String {
        (element.children ?? []).map { processNode($0, listDepth: listDepth) }.joined()
    }

    private static func processNode(_ node: XMLNode, listDepth: Int) -> String {
        switch node.kind {
        case .text:
            let text = (node.stringValue ?? "")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
            return text.replacingOccurrences(
                of: "[\\t\\n\\r ]+", with: " ", options: .regularExpression
            )
        case .element:
            guard let element = node as? XMLElement else { return "" }
            return processElement(element, listDepth: listDepth)
        default:
            return ""
        }
    }

    // MARK: - Element Processing

    private static func processElement(_ element: XMLElement, listDepth: Int) -> String {
        let tag = element.name?.lowercased() ?? ""

        switch tag {
        // Skip non-content
        case "head", "style", "script", "meta", "link", "noscript":
            return ""

        // Headings
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(tag.last!))!
            let prefix = String(repeating: "#", count: level)
            let content = processChildren(of: element, listDepth: listDepth).trimmed
            guard !content.isEmpty else { return "" }
            return "\n\n\(prefix) \(content)\n\n"

        // Paragraph
        case "p":
            let content = processChildren(of: element, listDepth: listDepth).trimmed
            guard !content.isEmpty else { return "" }
            return "\n\n\(content)\n\n"

        // Line break
        case "br":
            return "\n"

        // Bold
        case "strong", "b":
            return wrapInline(element, listDepth: listDepth, marker: "**")

        // Italic
        case "em", "i":
            return wrapInline(element, listDepth: listDepth, marker: "*")

        // Strikethrough
        case "s", "del", "strike":
            return wrapInline(element, listDepth: listDepth, marker: "~~")

        // Inline code
        case "code":
            if element.parent?.name?.lowercased() == "pre" {
                return (element.stringValue ?? "").replacingOccurrences(of: "\u{00A0}", with: " ")
            }
            let content = (element.stringValue ?? "").replacingOccurrences(of: "\u{00A0}", with: " ")
            guard !content.isEmpty else { return "" }
            return "`\(content)`"

        // Code block
        case "pre":
            let codeEl = (element.children ?? [])
                .compactMap { $0 as? XMLElement }
                .first { $0.name?.lowercased() == "code" }
            let content = (codeEl?.stringValue ?? element.stringValue ?? "").replacingOccurrences(of: "\u{00A0}", with: " ")
            let lang = codeEl?
                .attribute(forName: "class")?.stringValue?
                .components(separatedBy: .whitespaces)
                .first { $0.hasPrefix("language-") }?
                .replacingOccurrences(of: "language-", with: "") ?? ""
            return "\n\n```\(lang)\n\(content)\n```\n\n"

        // Link
        case "a":
            let href = element.attribute(forName: "href")?.stringValue ?? ""
            let content = processChildren(of: element, listDepth: listDepth).trimmed
            if href.isEmpty || content.isEmpty { return content }
            return "[\(content)](\(href))"

        // Image
        case "img":
            let src = element.attribute(forName: "src")?.stringValue ?? ""
            let alt = element.attribute(forName: "alt")?.stringValue ?? ""
            guard !src.isEmpty else { return "" }
            return "![\(alt)](\(src))"

        // Lists
        case "ul", "ol":
            let content = processChildren(of: element, listDepth: listDepth + 1)
            return listDepth == 0 ? "\n\n\(content)\n" : "\n\(content)"

        // List item
        case "li":
            let indent = String(repeating: "  ", count: max(0, listDepth - 1))
            let isOrdered = element.parent?.name?.lowercased() == "ol"
            let bullet: String
            if isOrdered {
                let siblings = (element.parent?.children ?? [])
                    .compactMap { $0 as? XMLElement }
                    .filter { $0.name?.lowercased() == "li" }
                let index = (siblings.firstIndex(of: element) ?? 0) + 1
                bullet = "\(index)."
            } else {
                bullet = "-"
            }

            var textParts: [String] = []
            var nestedContent = ""
            for child in element.children ?? [] {
                if let el = child as? XMLElement,
                   ["ul", "ol"].contains(el.name?.lowercased()) {
                    nestedContent += processElement(el, listDepth: listDepth)
                } else {
                    textParts.append(processNode(child, listDepth: listDepth))
                }
            }
            let text = textParts.joined().trimmed
            return "\(indent)\(bullet) \(text)\n\(nestedContent)"

        // Blockquote
        case "blockquote":
            let content = processChildren(of: element, listDepth: listDepth).trimmed
            guard !content.isEmpty else { return "" }
            let lines = content.components(separatedBy: "\n")
            let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
            return "\n\n\(quoted)\n\n"

        // Horizontal rule
        case "hr":
            return "\n\n---\n\n"

        // Table
        case "table":
            return "\n\n\(processTable(element))\n\n"

        // Pass-through containers
        default:
            return processChildren(of: element, listDepth: listDepth)
        }
    }

    // MARK: - Inline Formatting Helper

    private static func wrapInline(
        _ element: XMLElement, listDepth: Int, marker: String
    ) -> String {
        let content = processChildren(of: element, listDepth: listDepth)
        let trimmed = content.trimmed
        guard !trimmed.isEmpty else { return "" }
        // Preserve surrounding whitespace outside markers so Markdown parses correctly
        let leading = content.first?.isWhitespace == true ? " " : ""
        let trailing = content.last?.isWhitespace == true ? " " : ""
        return "\(leading)\(marker)\(trimmed)\(marker)\(trailing)"
    }

    // MARK: - Table Processing

    private static func processTable(_ table: XMLElement) -> String {
        var rows: [[String]] = []

        func extractRows(from element: XMLElement) {
            for child in element.children ?? [] {
                guard let el = child as? XMLElement else { continue }
                let tag = el.name?.lowercased() ?? ""
                switch tag {
                case "thead", "tbody", "tfoot":
                    extractRows(from: el)
                case "tr":
                    let cells = (el.children ?? [])
                        .compactMap { $0 as? XMLElement }
                        .filter { ["td", "th"].contains($0.name?.lowercased()) }
                        .map { processChildren(of: $0, listDepth: 0).trimmed }
                    if !cells.isEmpty { rows.append(cells) }
                default:
                    extractRows(from: el)
                }
            }
        }

        extractRows(from: table)
        guard !rows.isEmpty else { return "" }

        let colCount = rows.map(\.count).max() ?? 0
        guard colCount > 0 else { return "" }

        let padded = rows.map {
            $0 + Array(repeating: "", count: max(0, colCount - $0.count))
        }

        var lines: [String] = []
        lines.append("| " + padded[0].joined(separator: " | ") + " |")
        lines.append(
            "| " + Array(repeating: "---", count: colCount).joined(separator: " | ") + " |")
        for row in padded.dropFirst() {
            lines.append("| " + row.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Normalization

    private static func normalize(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ")
        result = result.replacingOccurrences(
            of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.replacingOccurrences(
            of: " +\\n", with: "\n", options: .regularExpression)
        return result.trimmed
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmed
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
