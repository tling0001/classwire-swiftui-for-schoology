import SwiftUI

struct SchoologyResourcePickerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String, String) -> Void
    @State private var collection: SchoologyResourceCollection?
    @State private var items: [SchoologyProfileItem] = []
    @State private var folderPath: [SchoologyProfileItem] = []
    @State private var selectedResource: SchoologyProfileItem?
    @State private var isLoadingItems = false
    @State private var error: String?
    private var currentFolderID: String? { folderPath.last?.id }

    var body: some View {
        NavigationStack {
            Group {
                if let collection { resourceList(collection) } else { collectionList }
            }
            .navigationTitle(collection?.title ?? "Choose a Resource")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        guard let selectedResource else { return }
                        onSelect(selectedResource.id, selectedResource.title)
                        dismiss()
                    }.disabled(selectedResource == nil)
                }
            }
            .task { await session.loadResources() }
        }
        .presentationDetents([.medium, .large])
    }

    private var collectionList: some View {
        List {
            if session.isLoadingResources && !session.hasLoadedResources {
                ProgressView("Loading resources…")
            } else if let message = session.resourcesError {
                ContentUnavailableView("Unable to Load Resources", systemImage: "exclamationmark.triangle", description: Text(message))
            } else {
                let collections = session.resourceCollections + session.resourceApps
                if collections.isEmpty {
                    ContentUnavailableView("No Resource Collections", systemImage: "folder")
                } else {
                    ForEach(collections) { item in
                        Button { Task { await open(item) } } label: {
                            Label(item.title, systemImage: item.category.symbol)
                        }
                    }
                }
            }
        }
    }

    private func resourceList(_ collection: SchoologyResourceCollection) -> some View {
        List {
            if isLoadingItems {
                ProgressView("Loading resources…")
            } else if let error {
                ContentUnavailableView("Unable to Load Resources", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView("No Resources", systemImage: "folder")
            } else {
                if !folderPath.isEmpty {
                    Button {
                        folderPath.removeLast()
                        Task { await loadItems(in: collection) }
                    } label: {
                        Label("Back to " + (folderPath.last?.title ?? collection.title), systemImage: "chevron.left")
                    }
                }
                ForEach(items) { item in
                    let folder = item.kind.lowercased() == "folder"
                    Button {
                        if folder {
                            folderPath.append(item)
                            Task { await loadItems(in: collection) }
                        } else {
                            selectedResource = item
                        }
                    } label: {
                        HStack {
                            Label(item.title, systemImage: folder ? "folder" : "doc")
                            Spacer()
                            if selectedResource?.id == item.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            else if folder { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func open(_ item: SchoologyResourceCollection) async {
        collection = item
        folderPath = []
        selectedResource = nil
        await loadItems(in: item)
    }

    private func loadItems(in collection: SchoologyResourceCollection) async {
        isLoadingItems = true
        error = nil
        defer { isLoadingItems = false }
        do { items = try await session.loadResourceItems(collectionID: collection.id, folderID: currentFolderID) }
        catch { self.error = error.localizedDescription }
    }
}
