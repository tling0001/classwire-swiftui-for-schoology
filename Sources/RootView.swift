import SwiftUI

private enum SchoologySidebarSelection: Hashable {
    case destination(AppDestination)
    case course(String)
    case group(String)
}

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedRoute: SchoologySidebarSelection = .destination(.home)
    @State private var detailPath: [String] = []

    var body: some View {
        Group {
            if session.isSignedIn {
                NavigationSplitView(selection: $selectedRoute) {
                    SchoologySidebar(selection: $selectedRoute)
                        #if os(macOS)
                        .navigationSplitViewColumnWidth(min: 250, ideal: 285, max: 360)
                        #endif
                } detail: {
                    NavigationStack(path: $detailPath) {
                        selectedRoot
                            .navigationDestination(for: String.self) { userID in
                                SchoologyPersonProfileView(userID: userID)
                            }
                    }
                    // Every sidebar selection, including an individual course or group,
                    // gets a distinct root identity. Pushed details remain on this stack.
                    .id(selectedRoute)
                }
                .navigationSplitViewStyle(.balanced)
                .task {
                    selectedRoute = .destination(session.destination)
                }
                .onChange(of: selectedRoute) { _, route in
                    detailPath.removeAll()
                    if case .destination(let destination) = route {
                        session.destination = destination
                    }
                }
                .onChange(of: session.destination) { _, destination in
                    selectedRoute = .destination(destination)
                }
                .onChange(of: session.pendingPersonProfileID) { _, userID in
                    guard let userID else { return }
                    detailPath.append(userID)
                    session.pendingPersonProfileID = nil
                }
            } else {
                SignInView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: session.isSignedIn)
    }

    @ViewBuilder
    private var selectedRoot: some View {
        switch selectedRoute {
        case .destination(let destination):
            DestinationView(destination: destination)
        case .course(let courseID):
            if let course = session.courses.first(where: { $0.id == courseID }) {
                SchoologyCourseProfileView(course: course)
            } else {
                ContentUnavailableView("Course unavailable", systemImage: "book.closed",
                    description: Text("This course is no longer in your loaded course list. Refresh and try again."))
            }
        case .group(let groupID):
            if let group = session.groups.first(where: { $0.id == groupID }) {
                GroupProfileView(group: group)
            } else {
                ContentUnavailableView("Group unavailable", systemImage: "person.3",
                    description: Text("This group is no longer in your loaded group list. Refresh and try again."))
            }
        }
    }
}

private struct SchoologySidebar: View {
    @Environment(AppSession.self) private var session
    @Binding var selection: SchoologySidebarSelection

    var body: some View {
        List(selection: $selection) {
            sidebarSections
        }
        .navigationTitle("Schoology")
        .listStyle(.sidebar)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var sidebarSections: some View {
        Section("Learning") {
            destinationRow(.home)
            DisclosureGroup {
                ForEach(session.courses) { course in
                    NavigationLink(value: SchoologySidebarSelection.course(course.id)) {
                        Label(course.title, systemImage: "book.closed").lineLimit(1)
                    }
                }
            } label: {
                Label("Courses", systemImage: "book.closed")
            }

            DisclosureGroup {
                ForEach(session.groups) { group in
                    NavigationLink(value: SchoologySidebarSelection.group(group.id)) {
                        Label(group.title, systemImage: "person.3").lineLimit(1)
                    }
                }
            } label: {
                Label("Groups", systemImage: "person.3")
            }
            destinationRow(.calendar)
        }

        Section("Communication") {
            ForEach([AppDestination.messages, .notifications, .requests]) { item in
                destinationRow(item)
            }
        }

        Section("More") {
            destinationRow(.profile)
            ForEach([AppDestination.resources, .grades]) { item in
                destinationRow(item)
            }
            if session.peopleDirectoryEnabled {
                destinationRow(.people)
            }
            destinationRow(.settings)
        }

        Section {
            Button(role: .destructive) {
                session.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func destinationRow(_ item: AppDestination) -> some View {
        NavigationLink(value: SchoologySidebarSelection.destination(item)) {
            Label(item.rawValue, systemImage: item.symbol)
        }
    }
}
