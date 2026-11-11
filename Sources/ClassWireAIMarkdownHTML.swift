import Foundation

/// Converts model-authored Markdown into a restricted Schoology rich-text HTML subset.
/// Raw HTML is escaped; only formatting tags generated here are submitted.
enum ClassWireAIMarkdownHTML {
    static func encode(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var output: [String] = []
        var paragraph: [String] = []
        var activeList: String?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            output.append("<p>" + paragraph.map(inline).joined(separator: "<br />") + "</p>")
            paragraph.removeAll(keepingCapacity: true)
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flushParagraph()
                if let listTag = activeList {
                    output.append("</\(listTag)>")
                    activeList = nil
                }
                continue
            }

            let bullet = line.range(of: #"^[-*+]\s+(.+)$"#, options: .regularExpression)
            let numbered = line.range(of: #"^\d+[.)]\s+(.+)$"#, options: .regularExpression)
            if bullet != nil || numbered != nil {
                flushParagraph()
                let kind = bullet != nil ? "ul" : "ol"
                if activeList != kind {
                    if let listTag = activeList { output.append("</\(listTag)>") }
                    output.append("<\(kind)>")
                    activeList = kind
                }
                let pattern = bullet != nil ? #"^[-*+]\s+"# : #"^\d+[.)]\s+"#
                let item = line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                output.append("<li>" + inline(item) + "</li>")
                continue
            }

            if let listTag = activeList {
                output.append("</\(listTag)>")
                activeList = nil
            }
            if let headingRange = line.range(of: #"^#{1,3}\s+"#, options: .regularExpression) {
                flushParagraph()
                output.append("<p><strong>" + inline(String(line[headingRange.upperBound...])) + "</strong></p>")
            } else {
                paragraph.append(rawLine)
            }
        }

        flushParagraph()
        if let listTag = activeList { output.append("</\(listTag)>") }
        return output.joined()
    }

    private static func inline(_ source: String) -> String {
        var value = escapeHTML(source)
        value = replacing(value, pattern: #"\[([^\]]+)\]\((https?://[^\s)]+)\)"#) {
            "<a href=\"\($0[2])\">\($0[1])</a>"
        }
        value = replacing(value, pattern: #"\x60([^\x60]+)\x60"#) { "<code>\($0[1])</code>" }
        value = replacing(value, pattern: #"\*\*(.+?)\*\*"#) { "<strong>\($0[1])</strong>" }
        value = replacing(value, pattern: #"__(.+?)__"#) { "<strong>\($0[1])</strong>" }
        value = replacing(value, pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) { "<em>\($0[1])</em>" }
        value = replacing(value, pattern: #"(?<!_)_([^_]+)_(?!_)"#) { "<em>\($0[1])</em>" }
        value = replacing(value, pattern: #"~~(.+?)~~"#) { "<s>\($0[1])</s>" }
        return value
    }

    private static func replacing(_ source: String, pattern: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        let nsSource = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        var result = source
        for match in matches.reversed() {
            let groups = (0..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : nsSource.substring(with: range)
            }
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(groups))
        }
        return result
    }

    private static func escapeHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}