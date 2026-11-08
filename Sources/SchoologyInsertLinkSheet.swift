import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct SchoologyInsertLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    let onError: (String) -> Void

    @State private var linkText = ""
    @State private var linkAddress = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Text", text: $linkText)
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif
                TextField("Link", text: $linkAddress)
                #if os(iOS)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                #endif
            }
            .navigationTitle("Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert", action: insert)
                        .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  linkAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, idealWidth: 420)
        .schoologyFittedSheet()
        #endif
    }

    private func insert() {
        let label = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        var address = linkAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !address.isEmpty else { return }
        if !address.contains("://") && !address.lowercased().hasPrefix("mailto:") {
            address = "https://" + address
        }
        guard let url = URL(string: address),
              ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? ""),
              url.scheme?.lowercased() == "mailto" || url.host != nil else {
            onError("Enter a valid web or email link.")
            return
        }
        var linkedText = AttributedString(label)
        linkedText.link = url
        text.replaceSelection(&selection, with: linkedText)
        dismiss()
    }
}
