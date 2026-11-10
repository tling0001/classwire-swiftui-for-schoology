import SwiftUI

struct SchoologyResourcePickerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let onSelect: ([SchoologyPickedResource]) -> Void

    @State private var collection: SchoologyResourceCollection?
    @State private var items: [SchoologyProfileItem] = []
    @State private var selectedResources: [String: SchoologyPickedResource] = [:]
    @State private var selectedApp: SchoologyResourceCollection?
    @State private var isLoadingItems = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let collection { resourceList(collection) }
                else { collectionList }
            }
            .navigationTitle(collection?.title ?? "Choose a Resource")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        onSelect(selectedResources.values.sorted {
                            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                        })
                        dismiss()
                    }
                    .disabled(selectedResources.isEmpty)
                }
            }
            .task { await session.loadResources() }
            .sheet(item: $selectedApp) { app in
                SchoologyResourceAppPickerView(app: app) { imported in
                    for resource in imported { selectedResources[resource.id] = resource }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var collectionList: some View {
        List {
            if session.isLoadingResources && !session.hasLoadedResources {
                ProgressView("Loading resources…")
            } else if let message = session.resourcesError,
                      session.resourceCollections.isEmpty && session.resourceApps.isEmpty {
                ContentUnavailableView("Unable to Load Resources", systemImage: "exclamationmark.triangle", description: Text(message))
            } else {
                ForEach(SchoologyResourceCategory.allCases) { category in
                    let entries = category == .apps
                        ? session.resourceApps
                        : session.resourceCollections.filter { $0.category == category }
                    Section(category.title) {
                        if entries.isEmpty {
                            Text("No resources").foregroundStyle(.secondary)
                        } else {
                            ForEach(entries) { item in
                                if category == .apps {
                                    Button { selectedApp = item } label: {
                                        resourceCollectionRow(item, isApp: true)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button { Task { await open(item) } } label: {
                                        resourceCollectionRow(item, isApp: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .schoologyInsetGroupedListStyle()
        .overlay(alignment: .top) {
            if session.isLoadingResources && session.hasLoadedResources {
                ProgressView().padding(.top, 8)
            } else if let message = session.resourcesError, !session.hasLoadedResources {
                ContentUnavailableView("Unable to Load Resources", systemImage: "exclamationmark.triangle", description: Text(message))
            }
        }
    }

    private func resourceCollectionRow(_ item: SchoologyResourceCollection, isApp: Bool) -> some View {
        HStack(spacing: 11) {
            if isApp, let imageURL = item.imageURL {
                AuthenticatedSchoologyImage(url: imageURL)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Image(systemName: isApp ? "app.fill" : item.typeID == "3" ? "book.closed" : "folder")
                    .font(.title3).foregroundStyle(SchoologyStyle.blue).frame(width: 32)
            }
            Text(item.title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: isApp ? "arrow.up.right" : "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func resourceList(_ collection: SchoologyResourceCollection) -> some View {
        SchoologyResourcesContentView(
            items: items,
            source: .collection(collectionID: collection.id),
            isLoading: isLoadingItems,
            error: error,
            emptyTitle: "No Resources",
            emptyDescription: "This collection is empty.",
            selection: $selectedResources
        ) {
            await loadItems(in: collection, folderID: collection.folderID)
        }
    }

    private func open(_ item: SchoologyResourceCollection) async {
        collection = item
        items = []
        error = nil
        await loadItems(in: item, folderID: item.folderID)
    }

    private func loadItems(in collection: SchoologyResourceCollection, folderID: String?) async {
        isLoadingItems = true
        error = nil
        defer { isLoadingItems = false }
        do {
            items = try await session.loadResourceItems(collectionID: collection.id, folderID: folderID)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
