import SwiftUI

struct SchoologyFittedSheetModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            content.presentationSizing(.fitted)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    func schoologyFittedSheet() -> some View {
        modifier(SchoologyFittedSheetModifier())
    }
}
