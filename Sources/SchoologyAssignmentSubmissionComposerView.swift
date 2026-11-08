import SwiftUI
import UniformTypeIdentifiers

/// Stages files and Schoology resources, then creates exactly one submission revision.
struct SchoologyAssignmentSubmissionComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @FocusState private var commentFocused: Bool
    let sectionID: String
    let assignmentID: String
    let onSubmitted: () -> Void

    @State private var selectedFiles: [URL] = []
    @State private var selectedResources: [String: String] = [:]
    @State private var uploadedFileIDs: [String: String] = [:]
    @State private var showingFileImporter = false
    @State private var showingResourcePicker = false
    @State private var isSubmitting = false
    @State private var uploadingFileID: String?
    @State private var completedUploadCount = 0
    @State private var errorMessage: String?
    @State private var comment = ""
    @State private var submissionCreated = false

    private var hasAttachments: Bool { !selectedFiles.isEmpty || !selectedResources.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Add to Submission") {
                    Button("Choose Files", systemImage: "doc.badge.plus") { showingFileImporter = true }
                        .disabled(isSubmitting)
                    Button("Choose Resources", systemImage: "folder.badge.plus") { showingResourcePicker = true }
                        .disabled(isSubmitting)
                }
                if !selectedFiles.isEmpty {
                    Section("Files") {
                        ForEach(selectedFiles, id: \.absoluteString) { file in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 9) {
                                    Image(systemName: "doc").foregroundStyle(.secondary)
                                    Text(file.lastPathComponent).lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if !isSubmitting {
                                        Button("Remove", systemImage: "xmark.circle") { removeFile(file) }
                                            .labelStyle(.iconOnly)
                                            .buttonStyle(.borderless)
                                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                                    }
                                }
                                if uploadedFileIDs[file.absoluteString] != nil {
                                    ProgressView(value: 1).tint(.green).accessibilityLabel("Upload complete")
                                } else if uploadingFileID == file.absoluteString {
                                    ProgressView().accessibilityLabel("Uploading \(file.lastPathComponent)")
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                if !selectedResources.isEmpty {
                    Section("Resources") {
                        ForEach(selectedResources.keys.sorted(), id: \.self) { resourceID in
                            HStack(spacing: 9) {
                                Image(systemName: "folder").foregroundStyle(.secondary)
                                Text(selectedResources[resourceID] ?? "Resource")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !isSubmitting {
                                    Button("Remove", systemImage: "xmark.circle") {
                                        selectedResources.removeValue(forKey: resourceID)
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove \(selectedResources[resourceID] ?? "resource")")
                                }
                            }
                        }
                    }
                }
                Section("Comment (Optional)") {
                    TextField("Add a comment…", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($commentFocused)
                }
                if isSubmitting && !selectedFiles.isEmpty {
                    Section("Upload Progress") {
                        ProgressView(value: Double(completedUploadCount), total: Double(max(selectedFiles.count, 1)))
                        Text("\(completedUploadCount) of \(selectedFiles.count) files uploaded")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Upload Submission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    #if os(iOS)
                    if commentFocused {
                        SchoologyKeyboardDoneToolbarButton { commentFocused = false }
                    } else if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill") { Task { await submit() } }.disabled(!hasAttachments || isSubmitting)
                    }
                    #else
                    if submissionCreated {
                        Button("Done") { dismiss() }
                    } else {
                        Button("Submit", systemImage: "paperplane.fill") { Task { await submit() } }.disabled(!hasAttachments || isSubmitting)
                    }
                    #endif
                }
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls where !selectedFiles.contains(where: { $0.absoluteString == url.absoluteString }) {
                    selectedFiles.append(url)
                }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingResourcePicker) {
            SchoologyResourcePickerView { resources in
                for resource in resources where selectedResources[resource.id] == nil {
                    selectedResources[resource.id] = resource.title
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func removeFile(_ file: URL) {
        selectedFiles.removeAll { $0.absoluteString == file.absoluteString }
        uploadedFileIDs[file.absoluteString] = nil
    }

    @MainActor
    private func submit() async {
        guard hasAttachments, !isSubmitting else { return }
        commentFocused = false
        isSubmitting = true
        errorMessage = nil
        completedUploadCount = uploadedFileIDs.count
        defer { isSubmitting = false; uploadingFileID = nil }
        do {
            var fileIDs: [String] = []
            for file in selectedFiles {
                if let existingID = uploadedFileIDs[file.absoluteString] {
                    fileIDs.append(existingID)
                    continue
                }
                uploadingFileID = file.absoluteString
                let fileID: String
                do {
                    let scoped = file.startAccessingSecurityScopedResource()
                    defer { if scoped { file.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: file)
                    guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
                    let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                    fileID = try await session.uploadAssignmentFile(data: data, filename: file.lastPathComponent, mime: mime)
                }
                uploadedFileIDs[file.absoluteString] = fileID
                fileIDs.append(fileID)
                completedUploadCount += 1
                uploadingFileID = nil
            }
            try await session.submitAssignmentFiles(
                fileIDs: fileIDs,
                resourceIDs: selectedResources.keys.sorted(),
                sectionID: sectionID,
                assignmentID: assignmentID
            )
            submissionCreated = true
            onSubmitted()
            let commentBody = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !commentBody.isEmpty {
                do {
                    try await session.postAssignmentComment(sectionID: sectionID, assignmentID: assignmentID, body: commentBody)
                } catch {
                    errorMessage = "Your submission was uploaded, but its comment could not be posted: \(error.localizedDescription)"
                    return
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
