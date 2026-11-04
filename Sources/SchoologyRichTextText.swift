import SwiftUI

/// Displays Schoology's link-preserving Markdown as native, tappable SwiftUI text.
struct SchoologyRichTextText: View {
    let value: String
    init(_ value: String) { self.value = value }
    var body: some View {
        if let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(value)
        }
    }
}
