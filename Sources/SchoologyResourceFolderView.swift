import SwiftUI

/// A folder is a navigable destination in the collection hierarchy. The parent
/// collection is retained so creation actions continue targeting the same collection.
struct SchoologyResourceFolderView: View {
    @Environment(AppSession.self) private var session

    let collection: SchoologyResourceCollection
    let folder: SchoologyProfileItem

    @State private var items: [SchoologyProfileItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var creationMode: SchoologyResourceCreationMode?

    var body: some View {
        SchoologyResourcesContentView(
            items: items,
            source: .collection(collectionID: collection.id),
            collection: collection,
            isLoading: loading,
            error: error,
            emptyTitle: "This folder is empty",
            emptyDescription: "Resources added to this folder will appear here."
        ) {
            await load()
        }
        .navigationTitle(folder.title)
        .task(id: "\(collection.id):\(folder.id)") { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await load() }
                }
                .disabled(loading)

                if session.canCreateResource(in: collection.id) {
                    Menu {
                        Button("New Resource Item", systemImage: "doc.badge.plus") {
                            creationMode = .resource
                        }
                        Button("New Folder", systemImage: "folder.badge.plus") {
                            creationMode = .folder
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create a resource item or folder in \(folder.title)")
                }
            }
        }
        .sheet(item: $creationMode) { mode in
            SchoologyResourceCreationSheet(
                mode: mode,
                collections: [collection],
                preferredCollectionID: collection.id,
                preferredFolderID: folder.id
            ) {
                await load()
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            items = try await session.loadResourceItems(
                collectionID: collection.id,
                folderID: folder.id
            )
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
