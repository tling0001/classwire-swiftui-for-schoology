import SwiftUI

private enum SchoologyCourseTab: String, CaseIterable, Identifiable {
    case materials = "Materials"
    case updates = "Updates"
    case grades = "Grades"
    case members = "Members"
    case upcoming = "Upcoming"
    case courseApps = "Course Apps"
    var id: String { rawValue }
}

struct SchoologyCourseProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let course: SchoologyCourse
    @State private var tab: SchoologyCourseTab = .materials
    @State private var materials: [SchoologyProfileItem] = []
    @State private var updates: [SchoologyActivity] = []
    @State private var courseApps: [SchoologyCourseApp] = []
    @State private var loadedTabs: Set<SchoologyCourseTab> = []
    @State private var loadingTabs: Set<SchoologyCourseTab> = []
    @State private var tabErrors: [SchoologyCourseTab: String] = [:]
    @State private var gradebook: SchoologyGradebook?
    @State private var members: [SchoologyProfileItem] = []
    @State private var upcoming: [SchoologyUpcomingEvent] = []
    @State private var schoolName = ""
    @State private var schoolID: String?
    @State private var permissions: SchoologyCoursePermissions?
    @State private var showingUpdateComposer = false
    @State private var showingResourceCreator = false

    private var profileNavigationTitle: String {
        #if os(iOS)
        horizontalSizeClass == .regular ? "" : course.title
        #else
        course.title
        #endif
    }

    private var resourceCreatorURL: URL? {
        let host = session.canadianServer ? "app.schoologyca.com" : "app.schoology.com"
        return URL(string: "https://\(host)/course/\(course.id)/materials")
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                wideLayout(width: proxy.size.width)
            } else {
                compactLayout
            }
        }
        .navigationTitle(profileNavigationTitle)
        .onAppear { session.setAICourseContext(courseID: course.id, title: course.title) }
        .toolbar {
            if permissions?.canPostUpdates == true || permissions?.canAddResources == true {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Course Actions", systemImage: "plus") {
                        if permissions?.canPostUpdates == true {
                            Button("Post Update", systemImage: "square.and.pencil") { showingUpdateComposer = true }
                        }
                        if permissions?.canAddResources == true {
                            Button("Add Resources", systemImage: "folder.badge.plus") { showingResourceCreator = true }
                        }
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadTab(tab, force: true) }
                } label: {
                    if loadingTabs.contains(tab) {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh")
                .disabled(loadingTabs.contains(tab))
            }
        }
        .sheet(isPresented: $showingUpdateComposer) {
            SchoologyUpdateComposerView(destinations: [
                SchoologyUpdateDestination(realm: "sections", resourceID: course.id, title: course.title)
            ]) { Task { await loadTab(.updates, force: true) } }
        }
        .navigationDestination(isPresented: $showingResourceCreator) {
            if let url = resourceCreatorURL {
                SchoologyEmbeddedWebView(url: url, title: "Add Resources")
            } else {
                ContentUnavailableView("Unable to open resources", systemImage: "exclamationmark.triangle")
            }
        }
        .task(id: tab) { await loadTab(tab) }
        .task(id: course.id) {
            async let loadedName = session.loadSchoolName(for: course)
            async let loadedSchoolID = session.loadSchoolID(for: course)
            async let loadedPermissions = session.loadCoursePermissions(courseID: course.id)
            schoolName = await loadedName
            schoolID = await loadedSchoolID
            permissions = await loadedPermissions
        }
        .refreshable { await loadTab(tab, force: true) }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            SchoologyProfileInfobox(title: course.title, subtitle: course.section.isEmpty ? nil : course.section,
                schoolName: schoolName.isEmpty ? nil : schoolName, schoolID: schoolID,
                imageURL: course.profileURL, fallbackSymbol: "book.closed.fill")
                .padding(.horizontal)
                .padding(.top, 12)
            Picker("Course section", selection: $tab) {
                ForEach(SchoologyCourseTab.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .schoologyNavigationTabPickerStyle()
            .padding(.horizontal)
            .padding(.vertical, 10)
            currentContent
        }
    }

    private func wideLayout(width: CGFloat) -> some View {
        let sidebarWidth = min(max(width * 0.19, 190), 280)
        let upcomingWidth = min(max(width * 0.2743, 250), 420)
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                SchoologyProfileHeroImage(url: course.profileURL, fallbackSymbol: "book.closed.fill").padding(12)
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach([SchoologyCourseTab.materials, .updates, .grades, .members, .courseApps]) { item in
                            courseTabButton(item)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.visible)
            }
            .frame(width: sidebarWidth)
            .background(.regularMaterial)
            Divider()
            VStack(spacing: 0) {
                SchoologyProfileInfobox(title: course.title, subtitle: course.section.isEmpty ? nil : course.section,
                    schoolName: schoolName.isEmpty ? nil : schoolName, schoolID: schoolID,
                    imageURL: course.profileURL, fallbackSymbol: "book.closed.fill", showsImage: false)
                    .padding(14)
                HStack {
                    Text(tab.rawValue).font(.headline)
                    Spacer()
                    if loadingTabs.contains(tab) { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Divider()
                currentContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text("Upcoming").font(.headline).padding(14)
                Divider()
                ScrollView {
                    UpcomingEventList(events: upcoming,
                        isLoading: loadingTabs.contains(.upcoming) && !loadedTabs.contains(.upcoming),
                        errorMessage: tabErrors[.upcoming], fallbackRealm: "sections", fallbackRealmID: course.id)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: upcomingWidth)
            .background(.thinMaterial)
            .task { await loadTab(.upcoming) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentContent: some View {
        Group {
            if loadingTabs.contains(tab) && currentIsEmpty {
                ProgressView("Loading \(tab.rawValue.lowercased())…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = tabErrors[tab], currentIsEmpty {
                ContentUnavailableView("Unable to load \(tab.rawValue.lowercased())",
                    systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func courseTabButton(_ item: SchoologyCourseTab) -> some View {
        Button { tab = item } label: {
            Label(item.rawValue, systemImage: courseTabSymbol(item))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .frame(minHeight: 44)
                .background(tab == item ? SchoologyStyle.blue.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tab == item ? SchoologyStyle.blue : .primary)
    }

    private func courseTabSymbol(_ item: SchoologyCourseTab) -> String {
        switch item {
        case .materials: "folder"
        case .updates: "text.bubble"
        case .grades: "chart.bar"
        case .members: "person.2"
        case .upcoming: "calendar"
        case .courseApps: "square.grid.2x2"
        }
    }

    @ViewBuilder private func courseAppLabel(_ app: SchoologyCourseApp) -> some View {
        HStack(spacing: 10) {
            if let logoURL = app.logoURL {
                AuthenticatedSchoologyImage(url: logoURL).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "square.grid.2x2").font(.title3).foregroundStyle(SchoologyStyle.blue).frame(width: 28, height: 28)
            }
            Text(app.title).font(.subheadline).lineLimit(2)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7).contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .materials:
            List {
                ForEach(materials) { item in
                    SchoologyInlineResourceItemRow(item: item, source: .course(courseID: course.id))
                }
            }
            .overlay { if materials.isEmpty && loadedTabs.contains(.materials) { ContentUnavailableView("No materials", systemImage: "folder") } }
        case .updates:
            ScrollView { RecentActivityView(activities: updates).padding() }
        case .grades:
            Group {
                if let gradebook {
                    ScrollView {
                        SchoologyGradebookView(gradebook: gradebook)
                    }
                } else if loadedTabs.contains(.grades) {
                    ContentUnavailableView("No grades available", systemImage: "chart.bar")
                }
            }
        case .members:
            SchoologyPeopleDirectoryView(items: members, membersMode: true, placeholder: "Search course members")
        case .courseApps:
            Group {
                if let courseAppsError = tabErrors[.courseApps], courseApps.isEmpty {
                    ContentUnavailableView("Unable to load course apps", systemImage: "exclamationmark.triangle", description: Text(courseAppsError))
                } else if courseApps.isEmpty {
                    ContentUnavailableView("No course apps", systemImage: "square.grid.2x2")
                } else {
                    List(courseApps) { app in
                        NavigationLink { SchoologyCourseAppLaunchView(courseID: course.id, app: app) } label: { courseAppLabel(app) }
                    }
                }
            }
        case .upcoming:
            ScrollView {
                UpcomingEventList(events: upcoming,
                    isLoading: loadingTabs.contains(.upcoming) && !loadedTabs.contains(.upcoming),
                    errorMessage: tabErrors[.upcoming], fallbackRealm: "sections", fallbackRealmID: course.id)
                    .padding()
            }
        }
    }

    private var currentIsEmpty: Bool {
        switch tab {
        case .materials: return materials.isEmpty
        case .updates: return updates.isEmpty
        case .grades: return gradebook == nil
        case .members: return members.isEmpty
        case .upcoming: return upcoming.isEmpty
        case .courseApps: return courseApps.isEmpty
        }
    }

    private func loadTab(_ selected: SchoologyCourseTab, force: Bool = false) async {
        guard force || !loadedTabs.contains(selected) else { return }
        guard !loadingTabs.contains(selected) else { return }
        loadingTabs.insert(selected)
        tabErrors[selected] = nil
        defer { loadingTabs.remove(selected) }
        do {
            switch selected {
            case .materials: materials = try await session.loadCourseMaterials(courseID: course.id)
            case .updates: updates = try await session.loadCourseUpdates(courseID: course.id)
            case .grades: gradebook = try await session.loadCourseGradebook(courseID: course.id)
            case .members: members = try await session.loadCourseMembers(courseID: course.id)
            case .upcoming: upcoming = await session.loadUpcomingEvents(for: course)
            case .courseApps: courseApps = try await session.loadCourseApps(courseID: course.id)
            }
            loadedTabs.insert(selected)
        } catch {
            tabErrors[selected] = error.localizedDescription
        }
    }
}

struct SchoologyCourseResourceFolderView: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let item: SchoologyProfileItem
    @State private var children: [SchoologyProfileItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if item.isFolder {
                List(children) { child in
                    SchoologyInlineResourceItemRow(item: child, source: .course(courseID: courseID))
                }
                .overlay {
                    if loading { ProgressView("Loading materials…") }
                    else if let error { ContentUnavailableView("Unable to load materials", systemImage: "exclamationmark.triangle", description: Text(error)) }
                    else if children.isEmpty { ContentUnavailableView("Empty folder", systemImage: "folder") }
                }
                .task(id: item.id) {
                    loading = true; error = nil
                    do { children = try await session.loadCourseMaterials(courseID: courseID, folderID: item.id) }
                    catch { self.error = error.localizedDescription }
                    loading = false
                }
                .navigationTitle(item.title)
            } else {
                SchoologyCourseMaterialDestinationView(courseID: courseID, item: item)
            }
        }
    }
}

struct SchoologyCourseMaterialDestinationView: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let item: SchoologyProfileItem
    @State private var resolvedAttachment: SchoologyAttachment?
    @State private var resolvedLinkURL: URL?
    @State private var isResolvingAttachment = false
    @State private var attachmentError: String?

    @ViewBuilder
    var body: some View {
        if item.isFolder {
            SchoologyCourseResourceFolderView(courseID: courseID, item: item)
        } else if item.kind.lowercased() == "document" {
            Group {
                if isResolvingAttachment {
                    ProgressView("Loading material…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let resolvedAttachment {
                    SchoologyAttachmentPreviewButton(attachment: resolvedAttachment, automaticallyPresent: true)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if let url = resolvedLinkURL ?? item.url {
                    SchoologyEmbeddedWebView(url: url, title: item.title)
                } else if let attachmentError {
                    ContentUnavailableView("Unable to open material", systemImage: "exclamationmark.triangle", description: Text(attachmentError))
                } else {
                    SchoologyProfileItemDetailSheet(item: item)
                }
            }
            .task(id: item.id) { await resolveAttachment() }
        } else if item.kind.contains("assignment") {
            SchoologyAssignmentDetailView(sectionID: courseID, assignmentID: item.id, title: item.title)
        } else if item.kind.lowercased() == "page" {
            SchoologyPageDetailView(courseID: courseID, pageID: item.id, title: item.title)
        } else if item.kind.contains("discussion") {
            SchoologyDiscussionDetailView(realm: "sections", realmID: courseID, itemID: item.id, title: item.title)
        } else if item.kind.contains("event") {
            SchoologyEventDetailView(realm: "sections", realmID: courseID, eventID: item.id, title: item.title)
        } else if ["assessment", "assessment_v2", "managed_assessment", "quiz"].contains(item.kind) {
            let host = session.canadianServer ? "app.schoologyca.com" : "app.schoology.com"
            if let url = URL(string: "https://\(host)/assignment/\(item.id)") {
                SchoologyEmbeddedWebView(url: url, title: item.title)
            } else {
                SchoologyProfileItemDetailSheet(item: item)
            }
        } else if let url = item.url ?? item.fileViewURL, isFileAttachment {
            SchoologyAttachmentPreviewButton(attachment: SchoologyAttachment(
                title: item.fileName.isEmpty ? item.title : item.fileName,
                url: url,
                viewURL: item.fileViewURL == url ? nil : item.fileViewURL
            ), automaticallyPresent: true)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let url = item.url {
            SchoologyEmbeddedWebView(url: url, title: item.title)
        } else {
            SchoologyProfileItemDetailSheet(item: item)
        }
    }

    private var isFileAttachment: Bool {
        let kind = item.kind.lowercased()
        if ["file", "document", "attachment", "file_attachment"].contains(kind) { return true }
        let ext = (item.url ?? item.fileViewURL)?.pathExtension.lowercased() ?? ""
        return ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                "jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
    }

    @MainActor
    private func resolveAttachment() async {
        guard resolvedAttachment == nil, !isResolvingAttachment else { return }
        isResolvingAttachment = true
        attachmentError = nil
        defer { isResolvingAttachment = false }
        do {
            let detail = try await session.loadCourseMaterialDetail(courseID: courseID, item: item)
            resolvedAttachment = detail.attachment
            resolvedLinkURL = detail.linkURL
        } catch {
            attachmentError = error.localizedDescription
        }
    }
}
