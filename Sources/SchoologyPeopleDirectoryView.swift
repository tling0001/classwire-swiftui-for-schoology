import SwiftUI

private enum SchoologyPeopleFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case members = "Members"
    case admins = "Admins"
    var id: String { rawValue }
}

private struct SchoologyPeopleSection: Identifiable {
    let title: String
    let people: [SchoologyProfileItem]
    var id: String { title }
}

struct SchoologyPeopleDirectoryView: View {
    let items: [SchoologyProfileItem]
    var membersMode = false
    var placeholder = "Search school directory"
    var onRefresh: (() async -> Void)? = nil

    @State private var searchText = ""
    @State private var filter: SchoologyPeopleFilter = .all
    @State private var isRefreshing = false

    private var visibleItems: [SchoologyProfileItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            let matchesFilter = !membersMode || filter == .all ||
                (filter == .admins ? item.isAdmin : !item.isAdmin)
            let searchable = [item.title, item.firstName, item.lastName, item.preferredName, item.role]
                .joined(separator: " ").localizedCaseInsensitiveContains(query)
            return matchesFilter && (query.isEmpty || searchable)
        }.sorted { lhs, rhs in
            if membersMode && filter == .all && lhs.isAdmin != rhs.isAdmin { return lhs.isAdmin }
            let last = lhs.lastName.localizedCaseInsensitiveCompare(rhs.lastName)
            if last != .orderedSame { return last == .orderedAscending }
            return lhs.firstName.localizedCaseInsensitiveCompare(rhs.firstName) == .orderedAscending
        }
    }

    private var sections: [SchoologyPeopleSection] {
        var result: [SchoologyPeopleSection] = []
        var remaining = visibleItems
        if membersMode && filter == .all {
            let admins = remaining.filter(\.isAdmin)
            if !admins.isEmpty {
                result.append(SchoologyPeopleSection(title: "Admins", people: admins))
                remaining.removeAll { $0.isAdmin }
            }
        }
        let grouped = Dictionary(grouping: remaining) {
            $0.lastName.first.map { String($0).uppercased() } ?? "#"
        }
        result.append(contentsOf: grouped.keys.sorted().map {
            SchoologyPeopleSection(title: $0, people: grouped[$0] ?? [])
        })
        return result
    }

    var body: some View {
        VStack(spacing: membersMode ? 8 : 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain).accessibilityLabel(placeholder)
                if !searchText.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") { searchText = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
                }
                if let onRefresh {
                    Button {
                        guard !isRefreshing else { return }
                        Task {
                            isRefreshing = true
                            await onRefresh()
                            isRefreshing = false
                        }
                    } label: {
                        if isRefreshing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .buttonStyle(.plain).disabled(isRefreshing).accessibilityLabel("Refresh people")
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, membersMode ? 16 : 0)

            if membersMode {
                Picker("Filter members", selection: $filter) {
                    ForEach(SchoologyPeopleFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Filter members")
                .padding(.horizontal, 16)
            }

            if visibleItems.isEmpty {
                ContentUnavailableView(
                    membersMode && filter == .admins ? "No admins found" :
                        membersMode && filter == .members ? "No members found" : "No people found",
                    systemImage: "person.2",
                    description: Text(searchText.isEmpty ? "There are no people to show." : "Try a different search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.people) { person in
                                NavigationLink {
                                    SchoologyPersonProfileView(userID: person.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let pictureURL = person.pictureURL {
                                            AuthenticatedSchoologyImage(url: pictureURL)
                                                .frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 9))
                                        } else {
                                            SchoologyAvatarPlaceholder(size: 38)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(directoryName(person)).font(.body.weight(.medium))
                                            if !person.preferredName.isEmpty {
                                                Text(person.preferredName).font(.caption).foregroundStyle(.secondary)
                                            } else if !person.role.isEmpty {
                                                Text(person.role).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if membersMode && person.isAdmin {
                                            Label("Admin", systemImage: "star.circle.fill")
                                                .font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                                        }
                                    }
                                    .padding(.vertical, 4).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(membersMode ? .plain : .automatic)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollContent)
            }
        }
        .padding(membersMode ? 0 : 16)
    }

    private func directoryName(_ person: SchoologyProfileItem) -> String {
        let name = [person.firstName, person.lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? person.title : name
    }
}

struct SchoologyPeopleDirectoryScreen: View {
    @Environment(AppSession.self) private var session
    @State private var people: [SchoologyProfileItem] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && people.isEmpty {
                ProgressView("Loading people…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, people.isEmpty {
                ContentUnavailableView("Unable to load people", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else {
                SchoologyPeopleDirectoryView(items: people, placeholder: "Search school directory") {
                    await load()
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do { people = try await session.loadPeopleDirectory() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
