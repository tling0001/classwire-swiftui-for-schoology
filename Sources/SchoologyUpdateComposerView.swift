import SwiftUI
import UniformTypeIdentifiers

struct SchoologyUpdateComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let destinations: [SchoologyUpdateDestination]
    let onPosted: () -> Void

    @State private var selectedDestinationID = ""
    @State private var bodyText = ""
    @State private var fileIDs: [String] = []
    @State private var resourceIDs: [String] = []
    @State private var attachmentNames: [String] = []
    @State private var showingFileImporter = false
    @State private var showingResourcePicker = false
    @State private var isUploading = false
    @State private var isPosting = false
    @State private var error: String?

    private var selectedDestination: SchoologyUpdateDestination? {
        destinations.first(where: { $0.id == selectedDestinationID }) ?? destinations.first
    }

    var body: some View {
        NavigationStack {
            Form {
                if destinations.count > 1 {
                    Section("Post to") {
                        Picker("Destination", selection: $selectedDestinationID) {
                            ForEach(destinations) { destination in
                                Text(destination.title).tag(destination.id)
                            }
                        }
                    }
                } else if let destination = selectedDestination {
                    Section("Post to") { LabeledContent("Destination", value: destination.title) }
                }

                Section("Update") {
                    TextField("Write an update…", text: $bodyText, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Attachments") {
                    Button("Attach File", systemImage: "paperclip") { showingFileImporter = true }
                        .disabled(isUploading || isPosting)
                    Button("Attach ClassWire Resource", systemImage: "folder") { showingResourcePicker = true }
                        .disabled(isUploading || isPosting)
                    ForEach(Array(attachmentNames.enumerated()), id: \.offset) { _, name in
                        Label(name, systemImage: "paperclip").foregroundStyle(.secondary)
                    }
                    if isUploading { ProgressView("Uploading attachment…") }
                }

                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Post Update")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isPosting || isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", systemImage: "paperplane.fill", action: post)
                        .disabled(isPosting || isUploading || selectedDestination == nil || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true, onCompletion: importFiles)
            .sheet(isPresented: $showingResourcePicker) {
                SchoologyResourcePickerView { resources in
                    for resource in resources where !resourceIDs.contains(resource.id) {
                        resourceIDs.append(resource.id)
                        attachmentNames.append(resource.title)
                    }
                }
            }
            .task {
                if selectedDestinationID.isEmpty { selectedDestinationID = destinations.first?.id ?? "" }
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let failure):
            error = failure.localizedDescription
        case .success(let urls):
            Task {
                isUploading = true
                error = nil
                defer { isUploading = false }
                do {
                    for url in urls {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                        let id = try await session.uploadMessageFile(data: data, filename: filename, mime: mime)
                        fileIDs.append(id)
                        attachmentNames.append(filename)
                    }
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func post() {
        guard !isPosting, let selectedDestination else { return }
        isPosting = true
        error = nil
        Task {
            do {
                try await session.postUpdate(destination: selectedDestination, body: bodyText, fileIDs: fileIDs, resourceIDs: resourceIDs)
                onPosted()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isPosting = false
        }
    }
}
