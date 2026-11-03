import SwiftUI

private enum SchoologyCourseTab: String, CaseIterable, Identifiable {
    case materials = "Materials"
    case assignments = "Assignments"
    case updates = "Updates"
    case grades = "Grades"
    case members = "Members"
    case upcoming = "Upcoming"
    var id: String { rawValue }
}

struct SchoologyCourseProfileView: View {
    @Environment(AppSession.self) private var session
    let course: SchoologyCourse
    @State private var tab: SchoologyCourseTab = .materials
    @State private var materials: [SchoologyProfileItem] = []
    @State private var assignments: [SchoologyProfileItem] = []
    @State private var updates: [SchoologyActivity] = []
    @State private var grades: [SchoologyProfileItem] = []
    @State private var members: [SchoologyProfileItem] = []
    @State private var upcoming: [SchoologyUpcomingEvent] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Course section", selection: $tab) {
                ForEach(SchoologyCourseTab.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            Group {
                if loading && currentIsEmpty {
                    ProgressView("Loading \(tab.rawValue.lowercased())…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error, currentIsEmpty {
                    ContentUnavailableView("Unable to load \(tab.rawValue.lowercased())", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    content
                }
            }
        }
        .navigationTitle(course.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(loading)
            }
        }
        .task(id: tab) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .materials:
            List(materials) { item in
                NavigationLink {
                    SchoologyCourseResourceFolderView(courseID: course.id, item: item)
                } label: {
                    Label(item.title, systemImage: item.kind == "folder" ? "folder" : "doc")
                }
            }
            .overlay { if materials.isEmpty && !loading { ContentUnavailableView("No materials", systemImage: "folder") } }
        case .assignments:
            List(assignments) { item in
                NavigationLink {
                    SchoologyAssignmentDetailView(sectionID: course.id, assignmentID: item.id, title: item.title)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                        if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .overlay { if assignments.isEmpty && !loading { ContentUnavailableView("No assignments", systemImage: "doc.text") } }
        case .updates:
            ScrollView { RecentActivityView(activities: updates).padding() }
        case .grades:
            List(grades) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                    if !item.subtitle.isEmpty { Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }
                    if !item.body.isEmpty { Text(item.body).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            .overlay { if grades.isEmpty && !loading { ContentUnavailableView("No grades available", systemImage: "chart.bar") } }
        case .members:
            List(members) { item in
                NavigationLink { SchoologyPersonProfileView(userID: item.id) } label: {
                    Label(item.title, systemImage: item.isAdmin ? "star.circle.fill" : "person.crop.circle")
                }
            }
            .overlay { if members.isEmpty && !loading { ContentUnavailableView("No members", systemImage: "person.2") } }
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
            .overlay { if upcoming.isEmpty && !loading { ContentUnavailableView("Nothing upcoming", systemImage: "calendar") } }
        }
    }

    private var currentIsEmpty: Bool {
        switch tab {
        case .materials: return materials.isEmpty
        case .assignments: return assignments.isEmpty
        case .updates: return updates.isEmpty
        case .grades: return grades.isEmpty
        case .members: return members.isEmpty
        case .upcoming: return upcoming.isEmpty
        }
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        error = nil
        do {
            switch tab {
            case .materials: materials = try await session.loadCourseMaterials(courseID: course.id)
            case .assignments: assignments = try await session.loadCourseAssignments(courseID: course.id)
            case .updates: updates = try await session.loadCourseUpdates(courseID: course.id)
            case .grades: grades = try await session.loadCourseGrades(courseID: course.id)
            case .members: members = try await session.loadCourseMembers(courseID: course.id)
            case .upcoming: upcoming = await session.loadUpcomingEvents(for: course)
            }
        } catch { self.error = error.localizedDescription }
        loading = false
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
                        SchoologyCourseResourceFolderView(courseID: courseID, item: child)
                    } label: {
                        Label(child.title, systemImage: child.kind == "folder" ? "folder" : "doc")
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
            } else if let url = item.url {
                SchoologyEmbeddedWebView(url: url, title: item.title)
            } else {
                SchoologyProfileItemDetailSheet(item: item)
            }
        }
    }
}
