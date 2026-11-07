import SwiftUI
struct ClassWireDemoModeBar: View {
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
            Button("Exit Demo", systemImage: "rectangle.portrait.and.arrow.right", action: onExit)
                .font(.subheadline.weight(.medium)).buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHint("Returns to the sign-in screen or your saved account.")
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
        .background { Rectangle().fill(.bar).ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Rectangle().fill(.quaternary).frame(height: 0.5) }
    }
}