import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct SchoologySubmissionFormattingBar: View {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    let onInsertLink: () -> Void

    @Environment(\.fontResolutionContext) private var fontResolutionContext

    private var typingAttributes: AttributeContainer {
        selection.typingAttributes(in: text)
    }

    private var isBold: Bool {
        (typingAttributes.font ?? .default).resolve(in: fontResolutionContext).isBold
    }

    private var isItalic: Bool {
        (typingAttributes.font ?? .default).resolve(in: fontResolutionContext).isItalic
    }

    private var isUnderlined: Bool {
        typingAttributes.underlineStyle != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            formatButton("Bold", symbol: "bold", isActive: isBold, action: toggleBold)
            formatButton("Italic", symbol: "italic", isActive: isItalic, action: toggleItalic)
            formatButton("Underline", symbol: "underline", isActive: isUnderlined, action: toggleUnderline)
            Button(action: onInsertLink) {
                Image(systemName: "link")
                    .font(.body.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Insert Link")
            .accessibilityHint("Adds a link to selected text or to text you type next.")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Text formatting")
    }

    private func formatButton(
        _ label: LocalizedStringKey,
        symbol: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    isActive ? Color.accentColor.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isActive ? "On" : "Off")
    }

    private func toggleBold() {
        text.transformAttributes(in: &selection) { attributes in
            let font = attributes.font ?? .default
            attributes.font = font.bold(!font.resolve(in: fontResolutionContext).isBold)
        }
    }

    private func toggleItalic() {
        text.transformAttributes(in: &selection) { attributes in
            let font = attributes.font ?? .default
            attributes.font = font.italic(!font.resolve(in: fontResolutionContext).isItalic)
        }
    }

    private func toggleUnderline() {
        text.transformAttributes(in: &selection) { attributes in
            attributes.underlineStyle = attributes.underlineStyle == nil ? .single : nil
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
enum SchoologySubmissionHTML {
    static func encode(_ text: AttributedString, fontContext: Font.Context) -> String {
        var html = ""

        for run in text.runs {
            let rawText = String(text[run.range].characters)
            guard !rawText.isEmpty else { continue }

            var content = escapeHTML(rawText).replacingOccurrences(of: "\n", with: "<br>\n")
            if let url = run.link,
               ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                content = "<a href=\"\(escapeHTML(url.absoluteString))\">\(content)</a>"
            }
            if run.underlineStyle != nil { content = "<u>\(content)</u>" }
            if run.font?.resolve(in: fontContext).isItalic == true { content = "<em>\(content)</em>" }
            if run.font?.resolve(in: fontContext).isBold == true { content = "<strong>\(content)</strong>" }
            html += content
        }

        return html
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
