import SwiftUI

/// A lightweight launch update notice. It keeps the current screen usable instead of
/// presenting a blocking alert as the app opens.
struct SchoologyUpdateBanner: View {
    let version: String
    let isInstalling: Bool
    let errorMessage: String?
    let installationNotice: String?
    let onInstall: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                Spacer(minLength: 8)
                Button("Later", action: onLater)
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
            }

            Text("Schoology \(version) is available. The update will download only after you choose Install update.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let installationNotice {
                Text(installationNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: onInstall) {
                    if isInstalling {
                        HStack(spacing: 8) { ProgressView(); Text("Preparing update…") }
                    } else {
                        Label("Install update", systemImage: "arrow.down.to.line")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
                .frame(minHeight: 44)
            }
        }
        .padding(14)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1) }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}
