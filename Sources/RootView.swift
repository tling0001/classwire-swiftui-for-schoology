import SwiftUI

private enum SchoologySidebarSelection: Hashable {
    case destination(AppDestination)
    case course(String)
    case group(String)
}

private enum SchoologyNavigationPath: Hashable {
    case person(String)
}

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppUpdateService.self) private var updates
    @AppStorage("schoology.update.dismissedVersion") private var dismissedUpdateVersion = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    @State private var selectedRoute: SchoologySidebarSelection = .destination(.home)
    @State private var detailPath: [SchoologyNavigationPath] = []

    var body: some View {
        Group {
            if session.isSignedIn {
                NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
                    SchoologySidebar(selection: $selectedRoute)
                        #if os(macOS)
                        .navigationSplitViewColumnWidth(min: 250, ideal: 285, max: 360)
                        #endif
                } detail: {
                    NavigationStack(path: $detailPath) {
                        selectedRoot(for: selectedRoute)
                            .id(selectedRoute)
                            .navigationDestination(for: SchoologyNavigationPath.self) { item in
                                switch item {
                                case .person(let userID):
                                    SchoologyPersonProfileView(userID: userID)
                                }
                            }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .task {
                    selectedRoute = .destination(session.destination)
                    #if os(iOS)
                    if session.isSignedIn { SchoologyBackgroundRefresh.schedule() }
                    #endif
                }
                #if os(macOS)
                .onChange(of: selectedRoute) { _, route in
                    detailPath.removeAll()
                    if case .destination(let destination) = route {
                        session.destination = destination
                    }
                }
                .onChange(of: session.destination) { _, destination in
                    let route = SchoologySidebarSelection.destination(destination)
                    if selectedRoute != route { selectedRoute = route }
                }
                #else
                #endif
                .onChange(of: session.pendingPersonProfileID) { _, userID in
                    guard let userID else { return }
                    detailPath.append(.person(userID))
                    session.pendingPersonProfileID = nil
                }
            } else {
                SignInView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: session.isSignedIn)
        .safeAreaInset(edge: .top, spacing: 0) {
            if shouldShowUpdateBanner, let version = updates.latestVersion {
                SchoologyUpdateBanner(
                    version: version,
                    isInstalling: updates.isInstallingUpdate,
                    errorMessage: updates.installErrorMessage,
                    installationNotice: updates.installationNotice,
                    onInstall: { Task { try? await updates.installUpdate() } },
                    onLater: { dismissedUpdateVersion = version }
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            #if os(iOS)
            if phase == .background, session.isSignedIn {
                SchoologyBackgroundRefresh.schedule()
            }
            #endif
        }
    }

    private var shouldShowUpdateBanner: Bool {
        updates.hasUpdate && updates.installURL != nil && (updates.latestVersion ?? "") != dismissedUpdateVersion
    }

    @ViewBuilder
    private func selectedRoot(for route: SchoologySidebarSelection) -> some View {
        switch route {
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
        #if os(macOS)
        List(selection: $selection) {
            sidebarSections
        }
        .navigationTitle(Text("ClassWire"))
        .listStyle(.sidebar)
        #else
        List {
            sidebarSections
        }
        .navigationTitle(Text("ClassWire"))
        .listStyle(.sidebar)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #endif
    }

    @ViewBuilder
    private var sidebarSections: some View {
        Section("Learning") {
            destinationRow(.home)
            DisclosureGroup {
                ForEach(session.courses) { course in
                    #if os(macOS)
                    Label(course.title, systemImage: "book.closed")
                        .lineLimit(1)
                        .tag(SchoologySidebarSelection.course(course.id))
                    #else
                    NavigationLink {
                        SchoologyCourseProfileView(course: course)
                    } label: {
                        Label(course.title, systemImage: "book.closed").lineLimit(1)
                    }
                    #endif
                }
            } label: {
                Label("Courses", systemImage: "book.closed")
            }

            DisclosureGroup {
                ForEach(session.groups) { group in
                    #if os(macOS)
                    Label(group.title, systemImage: "person.3")
                        .lineLimit(1)
                        .tag(SchoologySidebarSelection.group(group.id))
                    #else
                    NavigationLink {
                        GroupProfileView(group: group)
                    } label: {
                        Label(group.title, systemImage: "person.3").lineLimit(1)
                    }
                    #endif
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

    @ViewBuilder
    private func destinationRow(_ item: AppDestination) -> some View {
        #if os(macOS)
        Label(item.rawValue, systemImage: item.symbol)
            .tag(SchoologySidebarSelection.destination(item))
        #else
        NavigationLink {
            DestinationView(destination: item)
        } label: {
            Label(item.rawValue, systemImage: item.symbol)
        }
        #endif
    }
}
