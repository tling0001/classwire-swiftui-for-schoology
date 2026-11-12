import SwiftUI

private enum SchoologyActivityContentSegment: Identifiable {
    case text(id: Int, html: String)
    case image(id: Int, url: URL)

    var id: Int {
        switch self {
        case .text(let id, _), .image(let id, _): id
        }
    }
}

/// Renders the original order of HTML text and image elements from a Schoology
/// update. Image attachments that are not embedded in the body remain visible
/// after the authored body, matching Schoology's separate-attachment behavior.
struct SchoologyActivityContentView: View {
    let activity: SchoologyActivity
    let minimumFontSize: CGFloat

    private var segments: [SchoologyActivityContentSegment] {
        Self.makeSegments(body: activity.body, imageURLs: activity.imageURLs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                switch segment {
                case .text(_, let html):
                    SchoologyRichTextText(html, minimumFontSize: minimumFontSize)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(_, let url):
                    AuthenticatedSchoologyImage(url: url, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("Image in post")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func makeSegments(body: String, imageURLs: [URL]) -> [SchoologyActivityContentSegment] {
        let tagPattern = #"<img\b[^>]*>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) else {
            var fallback: [SchoologyActivityContentSegment] = []
            if !body.isEmpty { fallback.append(.text(id: 0, html: body)) }
            for (index, url) in imageURLs.enumerated() {
                fallback.append(.image(id: index + 1, url: url))
            }
            return fallback
        }

        let source = body as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = tagRegex.matches(in: body, range: fullRange)
        var output: [SchoologyActivityContentSegment] = []
        var seenImages = Set<String>()
        var cursor = 0
        var identity = 0

        for match in matches {
            let textRange = NSRange(location: cursor, length: match.range.location - cursor)
            appendText(source.substring(with: textRange), identity: &identity, to: &output)

            let tag = source.substring(with: match.range)
            if let url = imageURL(in: tag) {
                if seenImages.insert(url.absoluteString).inserted {
                    output.append(.image(id: identity, url: url))
                    identity += 1
                }
            } else {
                appendText(tag, identity: &identity, to: &output)
            }
            cursor = NSMaxRange(match.range)
        }

        if cursor < source.length {
            appendText(source.substring(from: cursor), identity: &identity, to: &output)
        }

        // imageURLs contains both body images and images exposed only as
        // Schoology file attachments. Append only those not already in the HTML.
        for url in imageURLs where seenImages.insert(url.absoluteString).inserted {
            output.append(.image(id: identity, url: url))
            identity += 1
        }
        return output
    }

    private static func appendText(
        _ html: String,
        identity: inout Int,
        to output: inout [SchoologyActivityContentSegment]
    ) {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        output.append(.text(id: identity, html: html))
        identity += 1
    }

    private static func imageURL(in tag: String) -> URL? {
        let pattern = #"(?is)\b(?:src|data-src|data-original|data-lazy-src)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        let rawURL = String(tag[range])
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
        return SchoologyValue.url(rawURL)
    }
}
