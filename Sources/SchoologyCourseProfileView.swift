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

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                wideLayout(width: proxy.size.width)
            } else {
                compactLayout
            }
        }
        .navigationTitle(course.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await loadTab(tab, force: true) } }.disabled(loadingTabs.contains(tab))
            }
        }
        .task(id: tab) { await loadTab(tab) }
        .task(id: course.id) { schoolName = await session.loadSchoolName(for: course) }
        .refreshable { await loadTab(tab, force: true) }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
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
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SchoologyProfileHeroImage(url: course.profileURL, fallbackSymbol: "book.closed.fill")
                    Text(course.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if !course.section.isEmpty { Text(course.section).font(.subheadline).foregroundStyle(.secondary) }
                    if !course.courseCode.isEmpty { Text(course.courseCode).font(.caption).foregroundStyle(.secondary) }
                    if !schoolName.isEmpty { Text(schoolName).font(.caption).foregroundStyle(SchoologyStyle.blue) }
                    Divider().padding(.vertical, 3)
                    ForEach([SchoologyCourseTab.materials, .updates, .grades, .members, .courseApps]) { item in
                        courseTabButton(item)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(width: max(190, width * 0.19))
            .background(.regularMaterial)

            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(tab.rawValue).font(.headline)
                    Spacer()
                    if loadingTabs.contains(tab) { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Divider()
                currentContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text("Upcoming").font(.headline).padding(14)
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if loadingTabs.contains(.upcoming) && upcoming.isEmpty {
                            ProgressView("Loading upcoming…").frame(maxWidth: .infinity).padding(.top, 24)
                        } else if upcoming.isEmpty && loadedTabs.contains(.upcoming) {
                            ContentUnavailableView("Nothing upcoming", systemImage: "calendar").padding(.top, 24)
                        }
                        ForEach(upcoming) { event in courseUpcomingRow(event) }
                    }
                    .padding(10)
                }
            }
            .frame(width: max(250, width * 0.2743))
            .background(.thinMaterial)
            .task { await loadTab(.upcoming) }
        }
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

    private func courseUpcomingRow(_ event: SchoologyUpcomingEvent) -> some View {
        NavigationLink {
            if event.type == "assignment", let assignmentID = event.assignmentID {
                SchoologyAssignmentDetailView(sectionID: event.sectionID ?? course.id, assignmentID: assignmentID, title: event.title)
            } else if event.type == "discussion", let discussionID = event.discussionID {
                SchoologyDiscussionDetailView(realm: "sections", realmID: course.id, itemID: discussionID, title: event.title)
            } else {
                SchoologyEventDetailView(realm: "sections", realmID: course.id, eventID: event.id, title: event.title)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text([event.typeLabel, event.timeLabel].filter { !$0.isEmpty }.joined(separator: " • "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .materials:
            List {
                ForEach(materials) { item in
                    SchoologyInlineCourseMaterialRow(courseID: course.id, item: item)
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
            List(upcoming) { event in
                NavigationLink {
                    if event.type == "assignment", let assignmentID = event.assignmentID {
                        SchoologyAssignmentDetailView(sectionID: event.sectionID ?? course.id, assignmentID: assignmentID, title: event.title)
                    } else if event.type == "discussion", let discussionID = event.discussionID {
                        SchoologyDiscussionDetailView(realm: "sections", realmID: course.id, itemID: discussionID, title: event.title)
                    } else {
                        SchoologyEventDetailView(realm: "sections", realmID: course.id, eventID: event.id, title: event.title)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                        Text([event.typeLabel, event.timeLabel].filter { !$0.isEmpty }.joined(separator: " • "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay { if upcoming.isEmpty && loadedTabs.contains(.upcoming) { ContentUnavailableView("Nothing upcoming", systemImage: "calendar") } }
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
            if item.kind == "folder" {
                List(children) { child in
                    NavigationLink {
                        SchoologyCourseMaterialDestinationView(courseID: courseID, item: child)
                    } label: {
                        Label(child.title, systemImage: child.kind == "folder" ? "folder" : child.kind.contains("discussion") ? "text.bubble" : child.kind.contains("assignment") ? "doc.text" : "doc")
                    }
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

    @ViewBuilder
    var body: some View {
        if item.kind == "folder" {
            SchoologyCourseResourceFolderView(courseID: courseID, item: item)
        } else if item.kind.contains("assignment") {
            SchoologyAssignmentDetailView(sectionID: courseID, assignmentID: item.id, title: item.title)
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
        } else if let url = item.url, isFileAttachment {
            SchoologyAttachmentPreviewButton(attachment: SchoologyAttachment(title: item.title, url: url))
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
        let ext = item.url?.pathExtension.lowercased() ?? ""
        return ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "csv", "txt", "rtf",
                "jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
    }
}
