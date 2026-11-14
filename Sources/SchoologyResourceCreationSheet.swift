import SwiftUI
import UniformTypeIdentifiers

enum SchoologyResourceCreationMode: String, Identifiable {
    case collection
    case resource
    case folder
    var id: String { rawValue }
}

struct SchoologyResourceCreationSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let mode: SchoologyResourceCreationMode
    let collections: [SchoologyResourceCollection]
    var preferredCollectionID: String? = nil
    var preferredFolderID: String? = nil
    let onCreated: () async -> Void

    @State private var selectedCollectionID = ""
    @State private var resourceType = "page"
    @State private var title = ""
    @State private var bodyText = ""
    @State private var notes = ""
    @State private var linkURL = ""
    @State private var embedCode = ""
    @State private var folderColor = "blue"
    @State private var selectedFileURL: URL?
    @State private var isImportingFile = false
    @State private var maxPoints = 100
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if mode == .collection { return true }
        guard collections.contains(where: { $0.id == selectedCollectionID }) else { return false }
        if mode == .folder { return true }
        switch resourceType {
        case "documentLink", "documentVideo":
            guard let url = URL(string: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        case "documentFile":
            return selectedFileURL != nil
        case "documentEmbed":
            return embedSourceURL != nil
        default:
            return true
        }
    }

    private var embedSourceURL: URL? {
        let pattern = #"(?is)<iframe\b[^>]*\bsrc\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: embedCode, range: NSRange(embedCode.startIndex..., in: embedCode)),
              let range = Range(match.range(at: 1), in: embedCode),
              let url = URL(string: String(embedCode[range])),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .resource || mode == .folder {
                    Section("Destination") {
                        Picker("Collection", selection: $selectedCollectionID) {
                            ForEach(collections) { collection in
                                Text(collection.title).tag(collection.id)
                            }
                        }
                        .disabled(preferredCollectionID != nil)
                    }
                }

                if mode == .resource {
                    Section("Resource") {
                        Picker("Type", selection: $resourceType) {
                            Text("Page").tag("page")
                            Text("Discussion").tag("discussion")
                            Text("Assignment").tag("assignment")
                            Section("Documents") {
                                Text("Document link").tag("documentLink")
                                Text("Upload a file").tag("documentFile")
                                Text("Video link").tag("documentVideo")
                                Text("Embed code").tag("documentEmbed")
                            }
                        }
                        TextField("Title", text: $title)
                        if resourceType == "page" || resourceType == "discussion" || resourceType == "assignment" {
                            TextField("Description", text: $bodyText, axis: .vertical)
                                .lineLimit(4...9)
                        } else if resourceType == "documentLink" || resourceType == "documentVideo" {
                            TextField(resourceType == "documentVideo" ? "Video web address" : "Web address", text: $linkURL)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                        } else if resourceType == "documentFile" {
                            Button {
                                isImportingFile = true
                            } label: {
                                Label(selectedFileURL?.lastPathComponent ?? "Choose File…", systemImage: "paperclip")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .accessibilityHint("Choose a document or media file to upload to Schoology")
                            if selectedFileURL != nil {
                                Button("Remove selected file", systemImage: "xmark.circle", role: .destructive) {
                                    selectedFileURL = nil
                                }
                            }
                        } else if resourceType == "documentEmbed" {
                            TextField("Paste iframe embed code", text: $embedCode, axis: .vertical)
                                .lineLimit(4...9)
                            Text("Use iframe embed code from a trusted provider. ClassWire validates the iframe source URL before submitting it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if resourceType == "assignment" {
                            Stepper("Maximum points: \(maxPoints)", value: $maxPoints, in: 0...10000)
                        }
                    }
                    Section("Notes") {
                        TextField("Resource notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                } else if mode == .folder {
                    Section("Folder") {
                        TextField("Folder name", text: $title)
                        Picker("Color", selection: $folderColor) {
                            ForEach(["blue", "black", "gray", "green", "orange", "pink", "purple", "red", "yellow"], id: \.self) { color in
                                Text(color.capitalized).tag(color)
                            }
                        }
                    }
                } else if mode == .collection {
                    Section("Collection") {
                        TextField("Collection name", text: $title)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : mode == .folder ? "Create Folder" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .task {
                if let preferredCollectionID {
                    selectedCollectionID = preferredCollectionID
                } else if selectedCollectionID.isEmpty {
                    selectedCollectionID = collections.first?.id ?? ""
                }
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.data]) { result in
            switch result {
            case .success(let url):
                selectedFileURL = url
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var navigationTitle: String {
        switch mode {
        case .collection: "New Collection"
        case .resource: "New Resource Item"
        case .folder: "New Folder"
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            if mode == .collection {
                try await session.createResourceCollection(title: title)
            } else if mode == .folder {
                try await session.createResourceTemplate(
                    collectionID: selectedCollectionID,
                    title: title,
                    type: "folder",
                    body: "",
                    notes: "",
                    linkURL: "",
                    maxPoints: 0,
                    folderID: preferredFolderID ?? "0",
                    folderColor: folderColor
                )
            } else {
                var filePayload: (Data, String, String)?
                if resourceType == "documentFile", let selectedFileURL {
                    filePayload = try await readSelectedFile(selectedFileURL)
                }
                try await session.createResourceTemplate(
                    collectionID: selectedCollectionID,
                    title: title,
                    type: resourceType,
                    body: bodyText,
                    notes: notes,
                    linkURL: linkURL,
                    maxPoints: maxPoints,
                    fileData: filePayload?.0,
                    fileName: filePayload?.1 ?? "",
                    fileMIME: filePayload?.2 ?? "",
                    embedCode: embedCode,
                    folderID: preferredFolderID ?? "0"
                )
            }
            await onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }

    private func readSelectedFile(_ url: URL) async throws -> (Data, String, String) {
        try await Task.detached(priority: .userInitiated) {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let values = try? url.resourceValues(forKeys: [.contentTypeKey])
            let mime = values?.contentType?.preferredMIMEType
                ?? UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            return (data, url.lastPathComponent, mime)
        }.value
    }
}
