import Foundation
import SwiftUI

/// Renders Schoology HTML as attributed text, retaining links, emphasis, and inline font styling.
struct SchoologyRichTextText: View {
    @Environment(AppSession.self) private var session
    let value: String

    init(_ value: String) { self.value = value }

    var body: some View {
        if Self.containsHTML(value) {
            VStack(alignment: .leading, spacing: 10) {
                if let attributed = Self.attributedHTML(value) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(value)
                }

                ForEach(embeddedURLs, id: \.absoluteString) { url in
                    SchoologyInlineEmbeddedContentView(url: url)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(value)
        }
    }

    private static func containsHTML(_ value: String) -> Bool {
        value.range(of: #"<[a-zA-Z][^>]*>"#, options: .regularExpression) != nil
    }

    private static func attributedHTML(_ html: String) -> AttributedString? {
        let document = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 1em; line-height: 1.45; }
          a { color: LinkText; }
          img, video, iframe { max-width: 100%; }
          p { margin: 0 0 .65em 0; }
        </style></head><body>\(html)</body></html>
        """
        guard let data = document.data(using: .utf8),
              let value = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else { return nil }
        return AttributedString(value)
    }

    private var embeddedURLs: [URL] {
        let pattern = #"(?is)<(?:iframe|embed)\b[^>]*?\b(?:src|data)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let baseHost = session.canadianServer ? "https://app.schoologyca.com" : "https://app.schoology.com"
        var seen = Set<String>()
        return regex.matches(in: value, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: value) else { return nil }
            let raw = String(value[valueRange]).replacingOccurrences(of: "&amp;", with: "&")
            guard let url = URL(string: raw, relativeTo: URL(string: baseHost))?.absoluteURL,
                  url.scheme?.lowercased() == "https",
                  url.host != nil,
                  seen.insert(url.absoluteString).inserted else { return nil }
            return url
        }
    }
}

private struct SchoologyInlineEmbeddedContentView: View {
    @Environment(AppSession.self) private var session
    let url: URL
    @State private var cookies: [SchoologyWebCookie] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading embedded content…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Unable to load embedded content", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                SchoologyCookieWebView(url: url, cookies: cookies)
            }
        }
        .task(id: url) {
            do { cookies = try await session.loadWebSessionCookies() }
            catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }
}
