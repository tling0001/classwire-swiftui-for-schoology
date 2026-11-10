import SwiftUI

/// A compact, button-anchored assistant for macOS and wide iPad layouts.
/// Compact iPhone/iPad layouts use the system sheet presentation.
struct ClassWireAIFloatingAssistantOverlay: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("classwire.ai.floatingButtonVisible") private var buttonVisible = true
    @State private var isPresented = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: controlAlignment) {
                if buttonVisible {
                    assistantButton
                        .padding(buttonEdgePadding)
                        .zIndex(1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: controlAlignment)
        }
        .allowsHitTesting(buttonVisible)
        .onChange(of: session.isAIAssistantPresented) { _, shouldPresent in
            if isPresented != shouldPresent {
                isPresented = shouldPresent
                if shouldPresent { buttonVisible = true }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isPresented)
    }

    private var assistantButton: some View {
        Button {
            setPresented(!isPresented)
        } label: {
            Image(systemName: isPresented ? "sparkles.rectangle.stack.fill" : "sparkles")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(ClassWireAIGlassButtonModifier())
        .contextMenu {
            Button("Hide ClassWire AI button", systemImage: "eye.slash", role: .destructive) {
                buttonVisible = false
                setPresented(false)
            }
        }
        .accessibilityLabel(isPresented ? "Close ClassWire AI" : "Open ClassWire AI")
        .accessibilityHint("Press and hold, or secondary-click, for assistant button options.")
        .accessibilityAddTraits(isPresented ? .isSelected : [])
        .popover(isPresented: popoverBinding, arrowEdge: .trailing) {
            NavigationStack {
                ClassWireAIAssistantView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") {
                                setPresented(false)
                            }
                        }
                    }
            }
            .frame(width: 520, height: 680)
        }
        #if os(iOS)
        .sheet(isPresented: compactSheetBinding) {
            NavigationStack {
                ClassWireAIAssistantView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "checkmark") {
                                setPresented(false)
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #endif
    }

    private func setPresented(_ value: Bool) {
        isPresented = value
        session.isAIAssistantPresented = value
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { isPresented && !usesCompactSheet },
            set: { setPresented($0) }
        )
    }

    private var controlAlignment: Alignment {
        #if os(macOS)
        .topTrailing
        #else
        .bottomTrailing
        #endif
    }

    private var buttonEdgePadding: EdgeInsets {
        #if os(macOS)
        EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 18)
        #else
        EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 18)
        #endif
    }

    private var usesCompactSheet: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact || verticalSizeClass == .compact
        #else
        false
        #endif
    }

    #if os(iOS)
    private var compactSheetBinding: Binding<Bool> {
        Binding(
            get: { isPresented && usesCompactSheet },
            set: { setPresented($0) }
        )
    }
    #endif
}

private struct ClassWireAIGlassButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.quaternary, lineWidth: 1)
                }
        }
    }
}
