import SwiftUI
struct ClassWireDemoModeBar: View {
    @Environment(AppSession.self) private var session
    let onExit: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Demo mode").font(.subheadline.weight(.semibold))
                    Text("Fictional sample data · No account connected").font(.caption).foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: "checkmark.seal.fill").foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            Menu {
                Button {
                    session.demoIsTeacher = false
                } label: {
                    Label("Student", systemImage: session.demoIsTeacher ? "person" : "checkmark.circle.fill")
                }
                Button {
                    session.demoIsTeacher = true
                } label: {
                    Label("Teacher", systemImage: session.demoIsTeacher ? "checkmark.circle.fill" : "person.crop.rectangle")
                }
            } label: {
                Label(session.demoIsTeacher ? "Teacher" : "Student", systemImage: "person.crop.circle")
            }
            .accessibilityLabel("Demo preview role")
            .accessibilityHint("Switch between student and teacher demo views.")
            .frame(minWidth: 44, minHeight: 44)
            Button("Exit Demo", systemImage: "rectangle.portrait.and.arrow.right", action: onExit)
                .font(.subheadline.weight(.medium)).buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHint("Returns to the sign-in screen or your saved account.")
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
        .background { Rectangle().fill(.bar) }
        .overlay(alignment: .bottom) { Rectangle().fill(.quaternary).frame(height: 0.5) }
    }
}

/// Keeps the demo-mode controls attached to the app shell rather than to a
/// particular NavigationSplitView column. This makes the bar persist while
/// compact iPhone navigation pushes sidebar destinations.
struct ClassWireDemoModeBarModifier: ViewModifier {
    @Environment(AppSession.self) private var session

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                if session.isDemoMode {
                    ClassWireDemoModeBar(onExit: session.exitDemoMode)
                }
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                if session.isDemoMode {
                    ClassWireDemoModeBar(onExit: session.exitDemoMode)
                }
            }
        }
        #else
        content
        #endif
    }
}

extension View {
    func classWireDemoModeBar() -> some View {
        modifier(ClassWireDemoModeBarModifier())
    }
}
