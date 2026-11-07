import SwiftUI

private enum ProfileTab: String, CaseIterable, Identifiable {
    case updates = "Updates", members = "Members", upcoming = "Upcoming"
    case discussions = "Discussions", albums = "Albums", resources = "Resources", info = "Info"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .updates: "text.bubble"
        case .members: "person.2"
        case .upcoming: "calendar"
        case .discussions: "bubble.left.and.bubble.right"
        case .albums: "photo.on.rectangle"
        case .resources: "folder"
        case .info: "info.circle"
        }
    }
}

struct GroupProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let group: SchoologyGroup
    @State private var profile: SchoologyGroupProfile?
    @State private var tab: ProfileTab = .updates
    @State private var isLoading = true
    @State private var error: String?
    @State private var schoolName = ""
    @State private var loadedTabs: Set<ProfileTab> = []
    @State private var loadingTabs: Set<ProfileTab> = []
    @State private var tabErrors: [ProfileTab: String] = [:]
    @State private var presentedAction: GroupProfileAction?
    @State private var selectedDetail: SchoologyProfileItem?

    var body: some View {
        Group {
            if isLoading { ProgressView("Loading group…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error { ContentUnavailableView("Unable to load group", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else if let profile { groupLayout(profile) }
        }
        .navigationTitle(profile?.group.title ?? group.title)
        .toolbar {
            if let permissions = profile?.permissions, hasGroupActions(permissions) {
                ToolbarItem(placement: .primaryAction) { groupActionsMenu(permissions) }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadTab(tab, force: true) }
                } label: {
                    if isLoading || loadingTabs.contains(tab) {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh")
                .disabled(isLoading || loadingTabs.contains(tab))
            }
        }
        .task { await load() }
        .onChange(of: tab) { _, selected in Task { await loadTab(selected) } }
        .sheet(item: $presentedAction) { action in
            GroupProfileActionSheet(groupID: group.id, action: action) {
                Task { await loadTab(tab, force: true) }
            }
        }
        .sheet(item: $selectedDetail) { item in
            SchoologyProfileItemDetailSheet(item: item)
        }
    }

    private func groupLayout(_ profile: SchoologyGroupProfile) -> some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                let sidebarWidth = min(max(proxy.size.width * 0.19, 176), 280)
                let upcomingWidth = min(max(proxy.size.width * 0.2743, 250), 420)
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        SchoologyProfileHeroImage(url: profile.group.pictureURL, fallbackSymbol: "person.3.fill").padding(12)
                        List(selection: Binding<ProfileTab?>(get: { tab }, set: { if let selected = $0 { tab = selected } })) {
                            ForEach([ProfileTab.updates, .members, .upcoming, .discussions, .albums, .resources]) { item in
                                Label(item.rawValue, systemImage: item.symbol).tag(item)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                    }
                    .frame(width: sidebarWidth)
                    .background(.regularMaterial)
                    Divider()
                    VStack(spacing: 0) {
                        SchoologyProfileInfobox(title: profile.group.title,
                            schoolName: schoolName.isEmpty ? nil : schoolName, schoolID: profile.group.schoolID,
                            imageURL: profile.group.pictureURL, fallbackSymbol: "person.3.fill", showsImage: false)
                            .padding(14)
                        groupContent(profile)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Upcoming").font(.headline).padding(14)
                        Divider()
                        ScrollView {
                            UpcomingEventList(events: profile.upcoming,
                                isLoading: loadingTabs.contains(.upcoming) && !loadedTabs.contains(.upcoming),
                                errorMessage: tabErrors[.upcoming], fallbackRealm: "groups", fallbackRealmID: group.id)
                                .padding(10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: upcomingWidth)
                    .background(.thinMaterial)
                    .task(id: isLoading) { if !isLoading { await loadTab(.upcoming) } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    SchoologyProfileInfobox(title: profile.group.title,
                        schoolName: schoolName.isEmpty ? nil : schoolName, schoolID: profile.group.schoolID,
                        imageURL: profile.group.pictureURL, fallbackSymbol: "person.3.fill")
                        .padding(.horizontal).padding(.top, 12)
                    Picker("Group section", selection: $tab) {
                        ForEach([ProfileTab.updates, .members, .upcoming, .discussions, .albums, .resources]) { Text($0.rawValue).tag($0) }
                    }.schoologyNavigationTabPickerStyle().padding()
                    groupContent(profile)
                }
            }
        }
    }

    private func groupHeader(_ profile: SchoologyGroupProfile) -> some View {
        VStack(spacing: 8) {
            SchoologyProfileHeroImage(url: profile.group.pictureURL, fallbackSymbol: "person.3.fill")
            Text(profile.group.title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tabButton(_ item: ProfileTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { tab = item }
        } label: {
            Label(item.rawValue, systemImage: item.symbol).frame(maxWidth: .infinity, alignment: .leading)
                .padding(10).background(tab == item ? SchoologyStyle.blue.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).foregroundStyle(tab == item ? SchoologyStyle.blue : .primary)
    }

    private func groupContent(_ profile: SchoologyGroupProfile) -> some View {
        VStack(spacing: 0) {
            if tab == .resources {
                SchoologyResourcesContentView(
                    items: profile.resources,
                    source: .group(groupID: group.id),
                    isLoading: loadingTabs.contains(.resources),
                    error: tabErrors[.resources],
                    emptyTitle: "No resources",
                    emptyDescription: "Resources shared with this group will appear here."
                ) {
                    await loadTab(.resources, force: true)
                }
            } else if loadingTabs.contains(tab) && tabIsEmpty(profile) {
                ProgressView("Loading \(tab.rawValue.lowercased())…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let tabError = tabErrors[tab], tabIsEmpty(profile) {
                ContentUnavailableView("Unable to load \(tab.rawValue.lowercased())",
                    systemImage: "exclamationmark.triangle", description: Text(tabError))
            } else {
                if tab == .members {
                    SchoologyPeopleDirectoryView(items: profile.members, membersMode: true, placeholder: "Search group members")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            switch tab {
                            case .updates: RecentActivityView(activities: profile.updates)
                            case .members: EmptyView()
                            case .upcoming:
                                UpcomingEventList(events: profile.upcoming, isLoading: loadingTabs.contains(.upcoming) && !loadedTabs.contains(.upcoming),
                                    errorMessage: tabErrors[.upcoming], fallbackRealm: "groups", fallbackRealmID: group.id)
                            case .discussions: profileRows(profile.discussions, empty: "No discussions")
                            case .albums: profileRows(profile.albums, empty: "No albums")
                            case .resources: EmptyView()
                            case .info: EmptyView()
                            }
                        }.padding()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupActionsMenu(_ permissions: SchoologyGroupPermissions) -> some View {
        Menu("Create", systemImage: "plus") {
            if permissions.canPostUpdates { Button("Post update", systemImage: "square.and.pencil") { presentedAction = .update } }
            if permissions.canCreateDiscussion { Button("Create discussion", systemImage: "bubble.left") { presentedAction = .discussion } }
            if permissions.canCreateEvent { Button("Create event", systemImage: "calendar.badge.plus") { presentedAction = .event } }
            if permissions.canCreateAlbum { Button("Create album", systemImage: "photo.badge.plus") { presentedAction = .album } }
            if permissions.canAddResources { Button("Add resource", systemImage: "folder.badge.plus") { presentedAction = .resource } }
        }
        .accessibilityHint("Shows actions allowed by this group's permissions")
    }

    private func hasGroupActions(_ permissions: SchoologyGroupPermissions) -> Bool {
        permissions.canPostUpdates || permissions.canCreateDiscussion || permissions.canCreateEvent ||
        permissions.canCreateAlbum || permissions.canAddResources
    }

    @ViewBuilder private func profileRows(_ items: [SchoologyProfileItem], empty: String) -> some View {
        if items.isEmpty { ContentUnavailableView(empty, systemImage: "tray") }
        else {
            ForEach(items) { item in
                NavigationLink {
                    switch tab {
                    case .discussions: SchoologyDiscussionDetailView(realm: "groups", realmID: group.id, itemID: item.id, title: item.title)
                    case .albums: SchoologyAlbumDetailView(groupID: group.id, albumID: item.id, title: item.title)
                    case .resources: SchoologyProfileItemDetailSheet(item: item)
                    default: SchoologyProfileItemDetailSheet(item: item)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        if !item.body.isEmpty { SchoologyRichTextText(item.body).foregroundStyle(.secondary).textSelection(.enabled) }
                        if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.tertiary) }
                        if item.kind == "folder" { Label("Folder", systemImage: "folder").font(.caption).foregroundStyle(.secondary) }
                        else if let url = item.url { Label(url.host ?? "Attachment", systemImage: "paperclip").font(.caption).foregroundStyle(.secondary) }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                }.buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        guard profile == nil else { await loadTab(tab); return }
        isLoading = true
        error = nil
        do {
            let loadedProfile = try await session.loadGroupProfile(group)
            profile = loadedProfile
            schoolName = await session.loadSchoolName(for: loadedProfile.group)
            isLoading = false
            await loadTab(tab)
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func tabIsEmpty(_ profile: SchoologyGroupProfile) -> Bool {
        switch tab {
        case .updates: profile.updates.isEmpty
        case .members: profile.members.isEmpty
        case .upcoming: profile.upcoming.isEmpty
        case .discussions: profile.discussions.isEmpty
        case .albums: profile.albums.isEmpty
        case .resources: profile.resources.isEmpty
        case .info: false
        }
    }

    private func loadTab(_ selected: ProfileTab, force: Bool = false) async {
        guard var cached = profile else { return }
        guard force || !loadedTabs.contains(selected) else { return }
        guard !loadingTabs.contains(selected) else { return }
        loadingTabs.insert(selected)
        tabErrors[selected] = nil
        defer { loadingTabs.remove(selected) }
        do {
            switch selected {
            case .updates: cached.updates = try await session.loadGroupUpdates(groupID: group.id)
            case .members: cached.members = try await session.loadGroupMembers(groupID: group.id)
            case .upcoming: cached.upcoming = try await session.loadGroupUpcoming(groupID: group.id)
            case .discussions: cached.discussions = try await session.loadGroupDiscussions(groupID: group.id)
            case .albums: cached.albums = try await session.loadGroupAlbums(groupID: group.id)
            case .resources: cached.resources = try await session.loadGroupResources(groupID: group.id)
            case .info: break
            }
            profile = cached
            loadedTabs.insert(selected)
        } catch {
            tabErrors[selected] = error.localizedDescription
        }
    }
}

struct SchoolProfileView: View {
    @Environment(AppSession.self) private var session
    let schoolID: String

    @State private var profile: SchoologySchoolProfile?
    @State private var tab: ProfileTab = .updates
    @State private var isLoading = true
    @State private var error: String?
    @State private var updates: [SchoologyActivity] = []
    @State private var upcoming: [SchoologyUpcomingEvent] = []
    @State private var discussions: [SchoologyProfileItem] = []
    @State private var schoolResources: [SchoologyProfileItem] = []
    @State private var loadedTabs: Set<ProfileTab> = []
    @State private var loadingTabs: Set<ProfileTab> = []
    @State private var tabErrors: [ProfileTab: String] = [:]
    @State private var discussionForbidden = false
    @State private var initialTabLoaded = false
    @State private var selectedDetail: SchoologyProfileItem?

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView("Loading school…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, profile == nil {
                ContentUnavailableView("Unable to load school", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let profile {
                schoolLayout(profile)
            }
        }
        .navigationTitle(profile?.school.title ?? "School")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        if profile == nil { await load() }
                        else { await loadTab(tab, force: true) }
                    }
                } label: {
                    if isLoading || loadingTabs.contains(tab) {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh")
                .disabled(isLoading || loadingTabs.contains(tab))
            }
        }
        .task(id: schoolID) { await load() }
        .onChange(of: tab) { _, selected in Task { await loadTab(selected) } }
        .sheet(item: $selectedDetail) { item in
            SchoologyProfileItemDetailSheet(item: item)
        }
    }

    private func schoolLayout(_ profile: SchoologySchoolProfile) -> some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                let sidebarWidth = min(max(proxy.size.width * 0.19, 176), 280)
                let upcomingWidth = min(max(proxy.size.width * 0.2743, 250), 420)
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        SchoologyProfileHeroImage(url: profile.school.pictureURL, fallbackSymbol: "building.2.crop.circle").padding(12)
                        List(selection: Binding<ProfileTab?>(get: { tab }, set: { if let selected = $0 { tab = selected } })) {
                            ForEach([ProfileTab.updates, .info, .upcoming, .resources, .discussions]) { item in
                                Label(item.rawValue, systemImage: item.symbol).tag(item)
                            }
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                    }
                    .frame(width: sidebarWidth)
                    .background(.regularMaterial)
                    Divider()
                    VStack(spacing: 0) {
                        SchoologyProfileInfobox(title: profile.school.title, imageURL: profile.school.pictureURL,
                            fallbackSymbol: "building.2.crop.circle", details: [profile.school.address, profile.school.phone],
                            showsImage: false).padding(14)
                        schoolContent(profile)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Upcoming").font(.headline).padding(14)
                        Divider()
                        ScrollView {
                            UpcomingEventList(events: upcoming,
                                isLoading: loadingTabs.contains(.upcoming) && !loadedTabs.contains(.upcoming),
                                errorMessage: tabErrors[.upcoming], fallbackRealm: "schools", fallbackRealmID: schoolID)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: upcomingWidth)
                    .background(.thinMaterial)
                    .task(id: initialTabLoaded) {
                        guard initialTabLoaded else { return }
                        await loadTab(.upcoming)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    SchoologyProfileInfobox(title: profile.school.title, imageURL: profile.school.pictureURL,
                        fallbackSymbol: "building.2.crop.circle", details: [profile.school.address, profile.school.phone])
                        .padding(.horizontal).padding(.top, 12)
                    Picker("School section", selection: $tab) {
                        ForEach([ProfileTab.updates, .info, .upcoming, .resources, .discussions]) { Text($0.rawValue).tag($0) }
                    }
                    .schoologyNavigationTabPickerStyle().padding()
                    schoolContent(profile)
                }
            }
        }
    }

    private func tabButton(_ item: ProfileTab) -> some View {
        Button { tab = item } label: {
            Label(item.rawValue, systemImage: item.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(tab == item ? SchoologyStyle.blue.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tab == item ? SchoologyStyle.blue : .primary)
    }

    @ViewBuilder
    private func schoolContent(_ profile: SchoologySchoolProfile) -> some View {
        if tab == .resources {
            SchoologyResourcesContentView(
                items: schoolResources,
                source: .school(schoolID: schoolID),
                isLoading: loadingTabs.contains(.resources) && !loadedTabs.contains(.resources),
                error: tabErrors[.resources],
                emptyTitle: "No resources",
                emptyDescription: "Resources shared with this school will appear here."
            ) {
                await loadTab(.resources, force: true)
            }
        } else {
            Group {
                if loadingTabs.contains(tab) && currentIsEmpty {
                    ProgressView("Loading \(tab.rawValue.lowercased())…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let tabError = tabErrors[tab], currentIsEmpty {
                    ContentUnavailableView(
                        "Unable to load \(tab.rawValue.lowercased())",
                        systemImage: "exclamationmark.triangle",
                        description: Text(tabError)
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            switch tab {
                            case .updates:
                                if updates.isEmpty {
                                    ContentUnavailableView("No updates", systemImage: "text.bubble")
                                } else {
                                    RecentActivityView(activities: updates)
                                }
                            case .info:
                                if profile.school.address.isEmpty && profile.school.phone.isEmpty {
                                    ContentUnavailableView("No school information", systemImage: "info.circle")
                                }
                                if !profile.school.address.isEmpty {
                                    LabeledContent("Address", value: profile.school.address)
                                }
                                if !profile.school.phone.isEmpty {
                                    LabeledContent("Phone", value: profile.school.phone)
                                }
                            case .upcoming:
                                UpcomingEventList(
                                    events: upcoming,
                                    fallbackRealm: "schools",
                                    fallbackRealmID: schoolID
                                )
                            case .resources:
                                EmptyView()
                            case .discussions:
                                if discussionForbidden {
                                    VStack(spacing: 10) {
                                        ContentUnavailableView(
                                            "School discussions unavailable",
                                            systemImage: "lock",
                                            description: Text("ClassWire cannot list school discussions for this account through the API.")
                                        )
                                        if let url = URL(string: "https://app.schoology.com/school/\(schoolID)/discussions") {
                                            Link("Open School Discussions", destination: url)
                                        }
                                    }
                                } else if discussions.isEmpty {
                                    ContentUnavailableView("No discussions", systemImage: "bubble.left.and.bubble.right")
                                } else {
                                    ForEach(discussions) { item in
                                        NavigationLink {
                                            SchoologyDiscussionDetailView(
                                                realm: "schools", realmID: schoolID,
                                                itemID: item.id, title: item.title
                                            )
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.title).font(.headline)
                                                if !item.body.isEmpty {
                                                    SchoologyRichTextText(item.body)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(3)
                                                }
                                            }
                                            .padding(14)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            default:
                                EmptyView()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var currentIsEmpty: Bool {
        switch tab {
        case .updates: updates.isEmpty
        case .info: profile?.school.address.isEmpty != false && profile?.school.phone.isEmpty != false
        case .upcoming: upcoming.isEmpty
        case .resources: schoolResources.isEmpty
        case .discussions: discussions.isEmpty && !discussionForbidden
        default: true
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            profile = try await session.loadSchoolProfile(schoolID)
            await loadTab(tab)
            initialTabLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadTab(_ selected: ProfileTab, force: Bool = false) async {
        guard profile != nil, selected != .members, selected != .albums else { return }
        guard force || !loadedTabs.contains(selected) else { return }
        guard !loadingTabs.contains(selected) else { return }
        loadingTabs.insert(selected)
        tabErrors[selected] = nil
        defer { loadingTabs.remove(selected) }
        do {
            switch selected {
            case .updates:
                updates = try await session.loadSchoolUpdates(schoolID: schoolID)
            case .info:
                profile = try await session.loadSchoolProfile(schoolID)
            case .upcoming:
                upcoming = try await session.loadSchoolUpcoming(schoolID: schoolID)
            case .resources:
                schoolResources = try await session.loadSchoolResources(schoolID: schoolID)
            case .discussions:
                discussionForbidden = false
                do {
                    discussions = try await session.loadSchoolDiscussions(schoolID)
                } catch let apiError as SchoologyAPIError {
                    if case .http(403, _) = apiError {
                        discussionForbidden = true
                    } else {
                        throw apiError
                    }
                }
            default:
                break
            }
            loadedTabs.insert(selected)
        } catch {
            tabErrors[selected] = error.localizedDescription
        }
    }
}
