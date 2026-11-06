import SwiftUI
import UniformTypeIdentifiers

struct SchoologyHomeCreateComposerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let destinations: [SchoologyHomeCreateDestination]
    let action: SchoologyHomeCreateAction
    let onCreated: () -> Void
    @State private var selectedDestinationID = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var published = true
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var graded = false
    @State private var maxPoints = ""
    @State private var factor = "1"
    @State private var allDay = true
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var rsvp = 0
    @State private var commentsEnabled = true
    @State private var fileIDs: [String] = []
    @State private var resourceIDs: [String] = []
    @State private var attachmentNames: [String] = []
    @State private var showingFileImporter = false
    @State private var showingResourcePicker = false
    @State private var isUploading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    private var eligible: [SchoologyHomeCreateDestination] { destinations.filter { action == .discussion ? $0.canCreateDiscussion : $0.canCreateEvent } }
    private var destination: SchoologyHomeCreateDestination? { eligible.first { $0.id == selectedDestinationID } ?? eligible.first }
    private var maxPointsValue: Double? { Double(maxPoints) }
    private var factorValue: Double { Double(factor) ?? 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Post to") {
                    if eligible.count > 1 {
                        Picker("Destination", selection: $selectedDestinationID) { ForEach(eligible) { Text($0.title).tag($0.id) } }
                    } else if let destination { LabeledContent("Destination", value: destination.title) }
                    else { ContentUnavailableView("No available destinations", systemImage: "lock", description: Text("Schoology hasn't granted permission to create this item in any loaded course or group.")) }
                }
                Section(action == .discussion ? "Discussion" : "Event") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $bodyText, axis: .vertical).lineLimit(4...10)
                }
                if action == .discussion {
                    Section("Discussion options") {
                        Toggle("Published", isOn: $published)
                        Toggle("Due Date", isOn: $hasDueDate)
                        if hasDueDate { DatePicker("Due", selection: $dueDate) }
                        Toggle("Enable Grading", isOn: $graded)
                        if graded {
                            TextField("Maximum points", text: $maxPoints)
                            TextField("Factor", text: $factor)
                        }
                    }
                } else {
                    Section("When") {
                        Toggle("All Day", isOn: $allDay)
                        DatePicker("Starts", selection: $startDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                        Toggle("End Date", isOn: $hasEndDate)
                        if hasEndDate { DatePicker("Ends", selection: $endDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute]) }
                    }
                    Section("Event options") {
                        Picker("RSVP", selection: $rsvp) { Text("No RSVP").tag(0); Text("Yes").tag(1); Text("Maybe").tag(2) }
                        Toggle("Enable comments", isOn: $commentsEnabled)
                    }
                }
                Section("Attachments") {
                    Button("Attach File", systemImage: "paperclip") { showingFileImporter = true }.disabled(isUploading || isSubmitting)
                    Button("Attach Schoology Resource", systemImage: "folder") { showingResourcePicker = true }.disabled(isUploading || isSubmitting)
                    ForEach(Array(attachmentNames.enumerated()), id: \.offset) { _, name in Label(name, systemImage: "paperclip").foregroundStyle(.secondary) }
                    if isUploading { ProgressView("Uploading attachment…") }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) } }
            }
            .navigationTitle(action.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSubmitting || isUploading) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "paperplane.fill") { Task { await submit() } }
                        .disabled(!canSubmit || isSubmitting || isUploading)
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
            .task { if selectedDestinationID.isEmpty { selectedDestinationID = eligible.first?.id ?? "" } }
            .interactiveDismissDisabled(isSubmitting || isUploading)
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 620, minHeight: 560, idealHeight: 720)
        #else
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        #endif
    }

    private var canSubmit: Bool {
        guard destination != nil, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if action == .discussion && graded { guard let points = maxPointsValue, points > 0, factorValue > 0 else { return false } }
        if action == .event && hasEndDate && endDate < startDate { return false }
        return true
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): errorMessage = error.localizedDescription
        case .success(let urls):
            Task {
                isUploading = true; defer { isUploading = false }
                do {
                    for url in urls {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                        let id = try await session.uploadMessageFile(data: data, filename: url.lastPathComponent, mime: mime)
                        fileIDs.append(id); attachmentNames.append(url.lastPathComponent)
                    }
                } catch { errorMessage = error.localizedDescription }
            }
        }
    }

    @MainActor private func submit() async {
        guard canSubmit, let destination else { return }
        isSubmitting = true; errorMessage = nil
        defer { isSubmitting = false }
        do {
            if action == .discussion {
                try await session.createHomeDiscussion(destination: destination, title: title, body: bodyText, published: published, dueDate: hasDueDate ? dueDate : nil, graded: graded, maxPoints: maxPointsValue, factor: factorValue, fileIDs: fileIDs, resourceIDs: resourceIDs)
            } else {
                try await session.createHomeEvent(destination: destination, title: title, description: bodyText, start: startDate, allDay: allDay, end: hasEndDate ? endDate : nil, rsvp: rsvp, commentsEnabled: commentsEnabled, fileIDs: fileIDs, resourceIDs: resourceIDs)
            }
            onCreated(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
