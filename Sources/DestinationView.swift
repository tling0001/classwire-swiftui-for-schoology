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
            case .messages: MessagesView()
            case .notifications: NotificationsView()
            case .resources: SchoologyResourcesView()
            case .grades: SchoologyGradesView()
            case .calendar: SchoologyCalendarView()
            case .profile: SignedInProfileView()
            case .people: SchoologyPeopleDirectoryScreen()
            case .settings: SettingsView()
            default: PlaceholderView(destination: destination)
            }
        }
        .navigationTitle(destination.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task {
                        switch destination {
                        case .resources: await session.loadResources(force: true)
                        case .grades: await session.loadUserGradeCourses(force: true)
                        case .calendar:
                            await session.loadCalendarUpcoming(force: true)
                            await session.loadCalendarMonth(Date(), force: true)
                        default: await session.refresh()
                        }
                    }
                }
                .disabled(session.isRefreshing || session.isLoadingResources || session.isLoadingUserGrades || session.isLoadingCalendar)
            }
        }
    }
}

struct HomeView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        @Bindable var model = session
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            welcomeHeader
                            Picker("Home", selection: Binding(
                                get: { model.homeSection == .upcoming ? HomeSection.recent : model.homeSection },
                                set: { model.homeSection = $0 }
                            )) {
                                Text(HomeSection.recent.rawValue).tag(HomeSection.recent)
                                Text(HomeSection.dashboard.rawValue).tag(HomeSection.dashboard)
                            }
                            .schoologyNavigationTabPickerStyle()
                            .accessibilityLabel("Home section")
                            switch session.homeSection {
                            case .recent: RecentActivityView(activities: session.activities, isLoading: !session.hasLoadedHomeActivities, errorMessage: session.homeActivitiesError)
                            case .dashboard: CourseDashboardView(courses: session.courses, isLoading: !session.hasLoadedHomeCourses, errorMessage: session.homeCoursesError)
                            case .upcoming: RecentActivityView(activities: session.activities, isLoading: !session.hasLoadedHomeActivities, errorMessage: session.homeActivitiesError)
                            }
                        }
                        .padding()
                        .frame(maxWidth: 980)
                        .frame(maxWidth: .infinity)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Upcoming").font(.headline).padding(14)
                        Divider()
                        ScrollView { UpcomingEventList(events: session.upcomingEvents, isLoading: !session.hasLoadedHomeUpcoming, errorMessage: session.homeUpcomingError).padding(12) }
                    }
                    .frame(width: max(270, proxy.size.width * 0.30))
                    .background(.thinMaterial)
                }
            } else {
                compactHome
            }
        }
        .refreshable { await session.refresh() }
        .task {
            if !session.hasLoadedHomeActivities || !session.hasLoadedHomeCourses || !session.hasLoadedHomeUpcoming {
                await session.refresh()
            }
        }
    }

    private var welcomeHeader: some View {
        HStack(spacing: 12) {
            if let user = session.user {
                if let avatar = user.pictureURL {
                    AuthenticatedSchoologyImage(url: avatar).frame(width: 48, height: 48).clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 42)).foregroundStyle(SchoologyStyle.blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome back").font(.subheadline).foregroundStyle(.secondary)
                    Text(user.nameDisplay).font(.title2.bold())
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var compactHome: some View {
        @Bindable var model = session
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                welcomeHeader
                Picker("Home", selection: $model.homeSection) {
                    ForEach(HomeSection.allCases) { section in Text(section.rawValue).tag(section) }
                }
                .schoologyNavigationTabPickerStyle()
                .accessibilityLabel("Home section")
                switch session.homeSection {
                case .recent: RecentActivityView(activities: session.activities)
                case .dashboard: CourseDashboardView(courses: session.courses)
                case .upcoming: UpcomingEventList(events: session.upcomingEvents)
                }
            }
            .padding()
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }
}

struct RecentActivityView: View {
    let activities: [SchoologyActivity]
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        if isLoading {
            ProgressView("Loading recent activity…").frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage, activities.isEmpty {
            ContentUnavailableView("Unable to load recent activity", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if activities.isEmpty {
            ContentUnavailableView(
                "No recent activity",
                systemImage: "text.bubble",
                description: Text("Your recent Schoology updates will appear here.")
            )
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(activities) { activity in
                    SchoologyActivityCard(activity: activity)
                }
            }
        }
    }
}

private struct SchoologyActivityCard: View {
    let activity: SchoologyActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let avatar = activity.avatarURL {
                    AuthenticatedSchoologyImage(url: avatar)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.authorName.isEmpty ? "Schoology" : activity.authorName)
                        .font(.subheadline.weight(.semibold))
                    if !activity.contextLabel.isEmpty {
                        Text(activity.contextLabel)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let date = activity.createdDate {
                    Text(date, style: .relative)
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            if !activity.body.isEmpty {
                Text(activity.body)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(activity.imageURLs, id: \.absoluteString) { imageURL in
                AuthenticatedSchoologyImage(url: imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !activity.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(activity.attachments) { attachment in
                        Link(destination: attachment.url) {
                            Label(attachment.title, systemImage: "paperclip")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()
            SchoologyPostActionsView(activity: activity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1))
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 38))
            .foregroundStyle(SchoologyStyle.blue.opacity(0.8))
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)
    }
}

private struct CourseDashboardView: View {
    let courses: [SchoologyCourse]
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        if isLoading {
            ProgressView("Loading courses…").frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage, courses.isEmpty {
            ContentUnavailableView("Unable to load courses", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if courses.isEmpty {
            ContentUnavailableView(
                "No courses found",
                systemImage: "books.vertical",
                description: Text("Courses available to your Schoology account will appear here.")
            )
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                ForEach(courses) { course in
                    CourseDashboardCard(course: course)
                }
            }
        }
    }
}

private struct CourseDashboardCard: View {
    @Environment(AppSession.self) private var session
    let course: SchoologyCourse
    @State private var schoolName = ""

    var body: some View {
        NavigationLink {
            SchoologyCourseProfileView(course: course)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let imageURL = course.profileURL {
                        GeometryReader { geometry in
                            AuthenticatedSchoologyImage(url: imageURL)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                    } else {
                        courseFallback
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    Text(course.title)
                        .font(.headline).foregroundStyle(.primary).lineLimit(2)
                    if !course.section.isEmpty {
                        Text(course.section).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if !schoolName.isEmpty {
                        Text(schoolName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 15))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.quaternary, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .task { schoolName = await session.loadSchoolName(for: course) }
    }

    private var courseFallback: some View {
        ZStack {
            LinearGradient(
                colors: [SchoologyStyle.blue, SchoologyStyle.blue.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct UpcomingEventList: View {
    @Environment(AppSession.self) private var session
    let events: [SchoologyUpcomingEvent]
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        if isLoading {
            ProgressView("Loading upcoming events…").frame(maxWidth: .infinity, minHeight: 180)
        } else if let errorMessage, events.isEmpty {
            ContentUnavailableView("Unable to load upcoming events", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if events.isEmpty {
            ContentUnavailableView(
                "No upcoming events",
                systemImage: "calendar",
                description: Text("Assignments, discussions, quizzes, and events will appear here.")
            )
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(upcomingDays) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.date.formatted(date: .complete, time: .omitted))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(day.events) { event in
                                NavigationLink {
                                    UpcomingEventDetailView(event: event)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: icon(for: event.type))
                                            .font(.title3)
                                            .foregroundStyle(SchoologyStyle.blue)
                                            .frame(width: 34)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text([event.typeLabel, event.timeLabel].filter { !$0.isEmpty }.joined(separator: " • "))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if event.id != day.events.last?.id {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1))
                    }
                }

                if !undatedEvents.isEmpty {
                    Text("Date not available")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(undatedEvents) { event in
                        NavigationLink(event.title, destination: UpcomingEventDetailView(event: event))
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var upcomingDays: [UpcomingDay] {
        let datedEvents = events.compactMap { event -> (Date, SchoologyUpcomingEvent)? in
            guard let date = event.date else { return nil }
            return (Calendar.current.startOfDay(for: date), event)
        }
        let grouped = Dictionary(grouping: datedEvents) { $0.0 }
        return grouped.keys.sorted().map { date in
            let dayEvents = (grouped[date] ?? []).map { $0.1 }.sorted {
                ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture)
            }
            return UpcomingDay(date: date, events: dayEvents)
        }
    }

    private var undatedEvents: [SchoologyUpcomingEvent] {
        events.filter { $0.date == nil }
    }

    private func icon(for type: String) -> String {
        switch type {
        case "assignment": "doc.text"
        case "assessment", "assessment_v2", "managed_assessment", "quiz": "doc.text.magnifyingglass"
        case "discussion": "text.bubble"
        case "external_tool": "app"
        case "event": "calendar"
        default: "calendar"
        }
    }
}

private struct UpcomingDay: Identifiable {
    let date: Date
    let events: [SchoologyUpcomingEvent]
    var id: Date { date }
}

private struct CourseDashboardDetailView: View {
    @Environment(AppSession.self) private var session
    let course: SchoologyCourse
    @State private var events: [SchoologyUpcomingEvent] = []
    @State private var schoolName = ""
    @State private var isLoading = true

    var body: some View {
        List {
            Section("Course") {
                LabeledContent("Course", value: course.title)
                if !course.section.isEmpty { LabeledContent("Section", value: course.section) }
                if !course.courseCode.isEmpty { LabeledContent("Course code", value: course.courseCode) }
                if !schoolName.isEmpty { LabeledContent("School", value: schoolName) }
            }

            Section("Upcoming") {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if events.isEmpty {
                    ContentUnavailableView("Nothing upcoming", systemImage: "calendar")
                } else {
                    ForEach(events) { event in
                        NavigationLink {
                            UpcomingEventDetailView(event: event)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.body.weight(.medium))
                                Text([event.typeLabel, event.date?.formatted(date: .abbreviated, time: .shortened) ?? ""]
                                    .filter { !$0.isEmpty }.joined(separator: " • "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(course.title)
        .task {
            async let eventRequest = session.loadUpcomingEvents(for: course)
            async let schoolRequest = session.loadSchoolName(for: course)
            events = await eventRequest
            schoolName = await schoolRequest
            isLoading = false
        }
    }
}

private struct UpcomingEventDetailView: View {
    let event: SchoologyUpcomingEvent

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Type", value: event.typeLabel)
                LabeledContent("Title", value: event.title)
                if let date = event.date {
                    LabeledContent("Date", value: date.formatted(date: .complete, time: .shortened))
                }
                if event.allDay {
                    LabeledContent("Time", value: "All day")
                }
            }
            if let url = event.webURL {
                Section {
                    Link(destination: url) {
                        Label("Open in Schoology", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .navigationTitle(event.typeLabel)
    }
}

struct CourseListView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        List(session.courses) { course in
            NavigationLink {
                SchoologyCourseProfileView(course: course)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
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
        }
        .overlay {
            if session.courses.isEmpty {
                ContentUnavailableView("No courses yet", systemImage: "books.vertical")
            }
        }
        .refreshable { await session.refresh() }
        .task { if session.courses.isEmpty { await session.refresh() } }
    }
}

struct GroupListView: View {
    @Environment(AppSession.self) private var session
    var body: some View {
        List(session.groups) { group in
            NavigationLink { GroupProfileView(group: group) } label: {
                Label(group.title, systemImage: "person.3.fill")
            }
        }
        .overlay { if session.groups.isEmpty { ContentUnavailableView("No groups yet", systemImage:"person.3") } }
        .refreshable { await session.refresh() }
        .task { if session.groups.isEmpty { await session.refresh() } }
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
