import SwiftUI

/// A consistent keyboard-dismissal action for iOS composer toolbars.
struct SchoologyKeyboardDoneToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(.blue)
        .accessibilityLabel("Done editing")
        .accessibilityHint("Dismisses the keyboard without submitting.")
    }
}
