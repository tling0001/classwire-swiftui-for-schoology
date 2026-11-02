import SwiftUI

struct DestinationView: View {
    let destination: AppDestination
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            switch destination {
            case .home: HomeView()
            case .courses: CourseListView()
            case .groups: GroupListView()
            case .settings: SettingsView()
            default: PlaceholderView(destination: destination)
            }
        }
        .navigationTitle(destination.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await session.refresh() }
                }
            }
        }
    }
}

struct HomeView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let user = session.user {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(SchoologyStyle.blue)
                        VStack(alignment: .leading) {
                            Text("Welcome back")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(user.nameDisplay).font(.title2.bold())
                        }
                    }
                    .padding(.bottom, 8)
                }
                sectionTitle("Recent Activity")
                if session.activities.isEmpty {
                    ContentUnavailableView(
                        "No recent activity",
                        systemImage: "text.bubble",
                        description: Text("Your Schoology updates will appear here.")
                    )
                } else {
                    ForEach(session.activities) { activity in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.title).font(.headline)
                            if !activity.body.isEmpty { Text(activity.body).foregroundStyle(.secondary) }
                            if !activity.created.isEmpty { Text(activity.created).font(.caption).foregroundStyle(.tertiary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await session.refresh() }
        .task { if session.activities.isEmpty { await session.refresh() } }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title3.bold())
    }
}

struct CourseListView: View {
    @Environment(AppSession.self) private var session
    var body: some View {
        List(session.courses) { course in
            Label {
                VStack(alignment: .leading) {
                    Text(course.title)
                    if !course.courseCode.isEmpty || !course.section.isEmpty {
                        Text([course.courseCode, course.section].filter { !$0.isEmpty }.joined(separator: " • "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "book.closed.fill").foregroundStyle(SchoologyStyle.blue)
            }
        }
        .overlay {
            if session.courses.isEmpty {
                ContentUnavailableView("No courses yet", systemImage: "books.vertical")
            }
        }
        .task { await session.refresh() }
    }
}

struct GroupListView: View {
    @Environment(AppSession.self) private var session
    var body: some View {
        List(session.groups) { group in
            Label(group.title, systemImage: "person.3.fill")
        }
        .overlay {
            if session.groups.isEmpty {
                ContentUnavailableView("No groups yet", systemImage: "person.3")
            }
        }
        .task { await session.refresh() }
    }
}

struct PlaceholderView: View {
    let destination: AppDestination
    var body: some View {
        ContentUnavailableView(
            destination.rawValue,
            systemImage: destination.symbol,
            description: Text("This Schoology area is being brought into the native app.")
        )
    }
}

struct MoreView: View {
    var body: some View {
        List {
            ForEach([AppDestination.requests, .resources, .grades, .people, .settings]) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.symbol)
                }
            }
        }
        .navigationTitle("More")
    }
}
