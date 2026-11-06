import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Renders Schoology HTML as attributed text, retaining links, emphasis, and inline font styling.
struct SchoologyRichTextText: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    let value: String
    let minimumFontSize: CGFloat?

    private static let attributedHTMLCache: NSCache<NSString, NSAttributedString> = {
        let cache = NSCache<NSString, NSAttributedString>()
        cache.countLimit = 160
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    init(_ value: String, minimumFontSize: CGFloat? = nil) {
        self.value = value
        self.minimumFontSize = minimumFontSize
    }

    var body: some View {
        if Self.containsHTML(value) {
            VStack(alignment: .leading, spacing: 10) {
                if let attributed = Self.attributedHTML(value, colorScheme: colorScheme, minimumFontSize: minimumFontSize) {
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

    private static func attributedHTML(_ html: String, colorScheme: ColorScheme, minimumFontSize: CGFloat?) -> AttributedString? {
        let cacheKey = "\(colorScheme == .dark ? "dark" : "light")|\(minimumFontSize.map { String(describing: $0) } ?? "default")|\(html)" as NSString
        if let cached = attributedHTMLCache.object(forKey: cacheKey) {
            return AttributedString(cached)
        }

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
              let imported = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else { return nil }

        let mutable = NSMutableAttributedString(attributedString: imported)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var lowContrastRanges: [NSRange] = []
        mutable.enumerateAttributes(in: fullRange) { attributes, range, _ in
            guard let rawForeground = attributes[.foregroundColor],
                  let foreground = rgbComponents(rawForeground, colorScheme: colorScheme) else { return }
            let background = attributes[.backgroundColor].flatMap {
                rgbComponents($0, colorScheme: colorScheme)
            } ?? rgbComponents(systemBackgroundColor, colorScheme: colorScheme)
            guard let background else { return }
            if contrastRatio(foreground, background) < 4.5 {
                lowContrastRanges.append(range)
            }
        }
        for range in lowContrastRanges {
            mutable.addAttribute(.foregroundColor, value: adaptiveLabelColor, range: range)
        }
        if let minimumFontSize {
            var resizedFonts: [(NSRange, Any)] = []
            mutable.enumerateAttribute(.font, in: fullRange) { rawFont, range, _ in
                #if os(iOS)
                if let font = rawFont as? UIFont, font.pointSize < minimumFontSize {
                    resizedFonts.append((range, UIFont(descriptor: font.fontDescriptor, size: minimumFontSize)))
                }
                #elseif os(macOS)
                if let font = rawFont as? NSFont, font.pointSize < minimumFontSize {
                    resizedFonts.append((range, NSFontManager.shared.convert(font, toSize: minimumFontSize)))
                }
                #endif
            }
            for (range, font) in resizedFonts {
                mutable.addAttribute(.font, value: font, range: range)
            }
        }
        attributedHTMLCache.setObject(mutable, forKey: cacheKey, cost: max(mutable.length * 2, 1))
        return AttributedString(mutable)
    }

    private static func contrastRatio(_ first: (Double, Double, Double), _ second: (Double, Double, Double)) -> Double {
        func luminance(_ color: (Double, Double, Double)) -> Double {
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.0) + 0.7152 * linear(color.1) + 0.0722 * linear(color.2)
        }
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func rgbComponents(_ rawColor: Any, colorScheme: ColorScheme) -> (Double, Double, Double)? {
        #if os(iOS)
        guard let color = rawColor as? UIColor else { return nil }
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (Double(red), Double(green), Double(blue))
        #elseif os(macOS)
        guard let color = (rawColor as? NSColor)?.usingColorSpace(.deviceRGB) else { return nil }
        return (Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
        #else
        return nil
        #endif
    }

    private static var systemBackgroundColor: Any {
        #if os(iOS)
        UIColor.systemBackground
        #elseif os(macOS)
        NSColor.windowBackgroundColor
        #else
        NSColor.white
        #endif
    }

    private static var adaptiveLabelColor: Any {
        #if os(iOS)
        UIColor.label
        #elseif os(macOS)
        NSColor.labelColor
        #else
        NSColor.black
        #endif
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
