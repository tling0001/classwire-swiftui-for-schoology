import SwiftUI

/// Presents the existing, fully functional ClassWire AI experience without
/// consuming a permanent row in the Schoology navigation sidebar.
struct ClassWireAIFloatingAssistantOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("classwire.ai.floatingButtonVisible") private var buttonVisible = true
    @State private var isPresented = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: controlAlignment) {
                if isPresented && !usesCompactSheet {
                    assistantPanel(in: geometry.size)
                        .padding(panelEdgePadding)
                        .transition(reduceMotion ? .identity : .move(edge: panelTransitionEdge).combined(with: .opacity))
                        .zIndex(1)
                }

                if buttonVisible {
                    assistantButton
                        .padding(buttonEdgePadding)
                        .zIndex(2)
                }
            }
            // Keep the assistant layer equal to the complete bounds proposed by its host overlay.
            // This makes the bottom-trailing alignment independent of the GeometryReader's ideal size.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: controlAlignment)
            .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isPresented)
        }
        .allowsHitTesting(buttonVisible || isPresented)
        #if os(iOS)
        .sheet(isPresented: compactSheetBinding) {
            NavigationStack {
                ClassWireAIAssistantView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "checkmark") {
                                isPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #endif
    }

    private var assistantButton: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: isPresented ? "sparkles.rectangle.stack.fill" : "sparkles")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(SchoologyStyle.blue)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(ClassWireAIGlassButtonModifier())
        .contextMenu {
            Button("Hide ClassWire AI button", systemImage: "eye.slash", role: .destructive) {
                buttonVisible = false
                isPresented = false
            }
        }
        .accessibilityLabel(isPresented ? "Close ClassWire AI" : "Open ClassWire AI")
        .accessibilityHint("Press and hold, or secondary-click, for assistant button options.")
        .accessibilityAddTraits(isPresented ? .isSelected : [])
    }

    private func assistantPanel(in size: CGSize) -> some View {
        let width = min(560, max(280, size.width - 36))
        let height = min(760, max(360, size.height - 104))

        return NavigationStack {
            ClassWireAIAssistantView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            isPresented = false
                        }
                    }
                }
        }
        .frame(width: width, height: height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 12)
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

    private var panelEdgePadding: EdgeInsets {
        #if os(macOS)
        EdgeInsets(top: 86, leading: 0, bottom: 0, trailing: 18)
        #else
        EdgeInsets(top: 0, leading: 0, bottom: 88, trailing: 18)
        #endif
    }

    private var panelTransitionEdge: Edge {
        #if os(macOS)
        .top
        #else
        .bottom
        #endif
    }

    private var usesCompactSheet: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    #if os(iOS)
    private var compactSheetBinding: Binding<Bool> {
        Binding(
            get: { isPresented && usesCompactSheet },
            set: { if !$0 { isPresented = false } }
        )
    }
    #endif
}

private struct ClassWireAIGlassButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.tint(SchoologyStyle.blue.opacity(0.18)).interactive(), in: .circle)
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(.quaternary, lineWidth: 1)
                }
        }
    }
}
