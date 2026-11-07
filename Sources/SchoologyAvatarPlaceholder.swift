import SwiftUI

/// A consistent rounded-square fallback for missing Schoology profile photos.
struct SchoologyAvatarPlaceholder: View {
    var size: CGFloat = 40
    var tint: Color = .secondary

    var body: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.52, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }
}
