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
    @State private var presentedAction: GroupProfileAction?
    @State private var selectedDetail: SchoologyProfileItem?

    var body: some View {
        Group {
            if isLoading { ProgressView("Loading group…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error { ContentUnavailableView("Unable to load group", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else if let profile { groupLayout(profile) }
        }
        .navigationTitle(profile?.group.title ?? group.title)
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(isLoading)
        }}
        .task { await load() }
        .sheet(item: $presentedAction) { action in
            GroupProfileActionSheet(groupID: group.id, action: action) {
                Task { await load() }
            }
        }
        .sheet(item: $selectedDetail) { item in
            SchoologyProfileItemDetailSheet(item: item)
        }
    }

    private func groupLayout(_ profile: SchoologyGroupProfile) -> some View {
        GeometryReader { proxy in
            if proxy.size.width >= 820 {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        groupHeader(profile)
                        ForEach([ProfileTab.updates,.members,.upcoming,.discussions,.albums,.resources]) { item in tabButton(item) }
                        Spacer()
                        if !schoolName.isEmpty, let schoolID = profile.group.schoolID {
                            NavigationLink { SchoolProfileView(schoolID: schoolID) } label: {
                                Label(schoolName, systemImage: "building.2")
                                    .font(.caption).foregroundStyle(SchoologyStyle.blue).padding(8)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(14).frame(width: 230).background(.regularMaterial)
                    Divider()
                    groupContent(profile).frame(maxWidth: .infinity)
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming").font(.headline)
                        ScrollView { LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(profile.upcoming) { event in eventCard(event) }
                        }}
                    }.padding(14).frame(width: 250).background(.thinMaterial)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Group section", selection: $tab) {
                        ForEach([ProfileTab.updates,.members,.upcoming,.discussions,.albums,.resources]) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).padding()
                    groupContent(profile)
                }
            }
        }
    }

    private func groupHeader(_ profile: SchoologyGroupProfile) -> some View {
        VStack(spacing: 8) {
            if let picture = profile.group.pictureURL {
                AuthenticatedSchoologyImage(url: picture).frame(height: 105).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "person.3.fill").font(.system(size: 38)).foregroundStyle(SchoologyStyle.blue).frame(maxWidth: .infinity).frame(height: 100).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
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
            if hasGroupActions(profile.permissions) {
                Menu {
                    if profile.permissions.canPostUpdates { Button("Post update", systemImage: "square.and.pencil") { presentedAction = .update } }
                    if profile.permissions.canCreateDiscussion { Button("Create discussion", systemImage: "bubble.left") { presentedAction = .discussion } }
                    if profile.permissions.canCreateEvent { Button("Create event", systemImage: "calendar.badge.plus") { presentedAction = .event } }
                    if profile.permissions.canCreateAlbum { Button("Create album", systemImage: "photo.badge.plus") { presentedAction = .album } }
                    if profile.permissions.canAddResources { Button("Add resource", systemImage: "folder.badge.plus") { presentedAction = .resource } }
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .accessibilityHint("Shows actions allowed by this group's permissions")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case .updates: profileRows(profile.updates, empty: "No group updates")
                    case .members: memberRows(profile.members)
                    case .upcoming: ForEach(profile.upcoming) { event in eventCard(event) }
                    case .discussions: profileRows(profile.discussions, empty: "No discussions")
                    case .albums: profileRows(profile.albums, empty: "No albums")
                    case .resources: profileRows(profile.resources, empty: "No resources")
                    case .info: EmptyView()
                    }
                }.padding()
            }
        }
    }

    private func hasGroupActions(_ permissions: SchoologyGroupPermissions) -> Bool {
        permissions.canPostUpdates || permissions.canCreateDiscussion || permissions.canCreateEvent ||
        permissions.canCreateAlbum || permissions.canAddResources
    }

    @ViewBuilder private func memberRows(_ items: [SchoologyProfileItem]) -> some View {
        if items.isEmpty { ContentUnavailableView("No members", systemImage: "person.3") }
        else {
            let admins = items.filter(\.isAdmin)
            let members = items.filter { !$0.isAdmin }
            if !admins.isEmpty {
                Section("Admins") { ForEach(admins) { memberRow($0) } }
            }
            Section("Members") { ForEach(members) { memberRow($0) } }
        }
    }

    private func memberRow(_ item: SchoologyProfileItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isAdmin ? "star.circle.fill" : "person.crop.circle")
                .foregroundStyle(item.isAdmin ? .yellow : SchoologyStyle.blue).font(.title2)
            VStack(alignment: .leading) {
                Text(item.title)
                if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }.padding(12).background(.background, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.quaternary))
    }

    @ViewBuilder private func profileRows(_ items: [SchoologyProfileItem], empty: String) -> some View {
        if items.isEmpty { ContentUnavailableView(empty, systemImage: "tray") }
        else {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Button { selectedDetail = item } label: { Text(item.title).font(.headline).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                    if !item.body.isEmpty { Text(item.body).foregroundStyle(.secondary).textSelection(.enabled) }
                    if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.tertiary) }
                    if let url = item.url { Link(destination: url) { Label("Open attachment", systemImage: "paperclip") }.font(.subheadline) }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
            }
        }
    }

    private func eventCard(_ event: SchoologyUpcomingEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.subheadline.weight(.semibold))
            Text([event.typeLabel,event.date?.formatted(date: .abbreviated,time: .shortened) ?? ""].filter { !$0.isEmpty }.joined(separator: " • "))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            profile = try await session.loadGroupProfile(group)
            if let id = profile?.group.schoolID, let auth = session.auth {
                let _ = auth
                let schoolProfile = try? await session.loadSchoolProfile(id)
                schoolName = schoolProfile?.school.title ?? ""
            }
        } catch let loadError { error = loadError.localizedDescription }
        isLoading = false
    }
}

struct SchoolProfileView: View {
    @Environment(AppSession.self) private var session
    let schoolID: String
    @State private var profile: SchoologySchoolProfile?
    @State private var discussions: [SchoologyProfileItem] = []
    @State private var tab: ProfileTab = .updates
    @State private var isLoading = true
    @State private var error: String?
    @State private var discussionForbidden = false
    @State private var selectedDetail: SchoologyProfileItem?

    var body: some View {
        Group {
            if isLoading { ProgressView("Loading school…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error { ContentUnavailableView("Unable to load school", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else if let profile { schoolLayout(profile) }
        }
        .navigationTitle(profile?.school.title ?? "School")
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(isLoading)
        }}
        .task { await load() }
        .sheet(item: $selectedDetail) { item in
            SchoologyProfileItemDetailSheet(item: item)
        }
    }

    private func schoolLayout(_ profile: SchoologySchoolProfile) -> some View {
        GeometryReader { proxy in
            if proxy.size.width >= 820 {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let image = profile.school.pictureURL {
                            AuthenticatedSchoologyImage(url: image).frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "building.2.crop.circle").font(.system(size: 40)).foregroundStyle(SchoologyStyle.blue).frame(maxWidth: .infinity).frame(height: 100)
                        }
                        Text(profile.school.title).font(.headline)
                        ForEach([ProfileTab.updates,.info,.upcoming,.resources,.discussions]) { item in tabButton(item) }
                        Spacer()
                    }.padding(14).frame(width: 230).background(.regularMaterial)
                    Divider()
                    schoolContent(profile).frame(maxWidth: .infinity)
                    Divider()
                    VStack(alignment: .leading) {
                        Text("Upcoming").font(.headline)
                        ForEach(profile.upcoming) { event in eventCard(event) }
                    }.padding(14).frame(width: 250).background(.thinMaterial)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("School section", selection: $tab) {
                        ForEach([ProfileTab.updates,.info,.upcoming,.resources,.discussions]) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).padding()
                    schoolContent(profile)
                }
            }
        }
    }

    private func tabButton(_ item: ProfileTab) -> some View {
        Button {
            tab = item
            if item == .discussions { Task { await loadDiscussions() } }
        } label: {
            Label(item.rawValue, systemImage: item.symbol).frame(maxWidth: .infinity, alignment: .leading)
                .padding(10).background(tab == item ? SchoologyStyle.blue.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).foregroundStyle(tab == item ? SchoologyStyle.blue : .primary)
    }

    private func schoolContent(_ profile: SchoologySchoolProfile) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case .updates: rows(profile.updates, empty: "No school updates")
                    case .info:
                        if profile.school.address.isEmpty && profile.school.phone.isEmpty { ContentUnavailableView("No school information", systemImage: "info.circle") }
                        if !profile.school.address.isEmpty { LabeledContent("Address", value: profile.school.address) }
                        if !profile.school.phone.isEmpty { LabeledContent("Phone", value: profile.school.phone) }
                    case .upcoming: ForEach(profile.upcoming) { event in eventCard(event) }
                    case .resources: rows(profile.resources, empty: "No resources")
                    case .discussions:
                        if discussionForbidden {
                            VStack(spacing: 10) {
                                ContentUnavailableView("School discussions unavailable", systemImage: "lock", description: Text("Schoology does not allow this account to list school discussions through the API."))
                                if let url = URL(string: "https://app.schoology.com/school/\(schoolID)/discussions") {
                                    Link("Open School Discussions", destination: url)
                                }
                            }
                        }
                        else { rows(discussions, empty: "No discussions") }
                    default: EmptyView()
                    }
                }.padding()
            }
        }.onChange(of: tab) { _, value in if value == .discussions { Task { await loadDiscussions() } } }
    }

    @ViewBuilder private func rows(_ items: [SchoologyProfileItem], empty: String) -> some View {
        if items.isEmpty { ContentUnavailableView(empty, systemImage: "tray") }
        else { ForEach(items) { item in
            VStack(alignment: .leading, spacing: 6) {
                Button { selectedDetail = item } label: { Text(item.title).font(.headline).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                if !item.body.isEmpty { Text(item.body).foregroundStyle(.secondary).textSelection(.enabled) }
                if let url = item.url { Link(destination: url) { Label("Open", systemImage: "arrow.up.right") } }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        }}
    }

    private func eventCard(_ event: SchoologyUpcomingEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.subheadline.weight(.semibold))
            Text([event.typeLabel,event.date?.formatted(date: .abbreviated,time: .shortened) ?? ""].filter { !$0.isEmpty }.joined(separator: " • "))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private func load() async {
        isLoading = true; error = nil
        do { profile = try await session.loadSchoolProfile(schoolID) }
        catch let loadError { error = loadError.localizedDescription }
        isLoading = false
    }

    private func loadDiscussions() async {
        discussionForbidden = false
        do { discussions = try await session.loadSchoolDiscussions(schoolID) }
        catch {
            if let apiError = error as? SchoologyAPIError, case .http(403, _) = apiError { discussionForbidden = true }
            else { self.error = error.localizedDescription }
        }
    }
}
