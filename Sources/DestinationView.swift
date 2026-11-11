import SwiftUI
#if os(iOS)
import UserNotifications
#endif

struct DestinationView: View {
    let destination: AppDestination
    @Environment(AppSession.self) private var session

    private var isRefreshingDestination: Bool {
        session.isRefreshing || session.isLoadingResources || session.isLoadingUserGrades || session.isLoadingCalendar
    }

    var body: some View {
        Group {
            switch destination {
            case .home: HomeView()
            case .courses: CourseListView()
            case .groups: GroupListView()
            case .aiAssistant: ClassWireAIAssistantView()
            case .messages: MessagesView()
            case .notifications: NotificationsView()
            case .resources: SchoologyResourcesView()
            case .grades: SchoologyGradesView()
            case .calendar: SchoologyCalendarView()
            case .profile:
                if let userID = session.user?.id {
                    SchoologyPersonProfileView(userID: userID)
                } else {
                    ContentUnavailableView("Profile unavailable", systemImage: "person.crop.circle")
                }
            case .people: SchoologyPeopleDirectoryScreen()
            case .settings: SettingsView()
            default: PlaceholderView(destination: destination)
            }
        }
        .navigationTitle(destination.rawValue)
        .onAppear {
            if session.destination != destination {
                session.destination = destination
            }
        }
        .toolbar {
            if destination != .aiAssistant && destination != .messages && destination != .notifications && destination != .profile {
                ToolbarItem(placement: .primaryAction) {
                    Button {
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
                    } label: {
                        if isRefreshingDestination {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh")
                    .disabled(isRefreshingDestination)
                }
            }
        }
    }
}

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var postableDestinations: [SchoologyUpdateDestination] = []
    @State private var createDestinations: [SchoologyHomeCreateDestination] = []
    @State private var showingUpdateComposer = false
    @State private var selectedCreateAction: SchoologyHomeCreateAction?
    @AppStorage("schoology.notifications.promptDismissed") private var didDismissNotificationPrompt = false
    @State private var shouldShowNotificationPrompt = false
    @State private var notificationPromptError: String?

    var body: some View {
        @Bindable var model = session
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            welcomeHeader
                            notificationPermissionPrompt
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
        .refreshable {
            await session.refresh()
            postableDestinations = await session.loadPostableUpdateDestinations()
            createDestinations = await session.loadHomeCreateDestinations()
        }
        .toolbar {
            if !postableDestinations.isEmpty || !createDestinations.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Create", systemImage: "plus") {
                        if !postableDestinations.isEmpty { Button("Post Update", systemImage: "square.and.pencil") { showingUpdateComposer = true } }
                        if createDestinations.contains(where: \.canCreateDiscussion) { Button("Discussion", systemImage: "text.bubble") { selectedCreateAction = .discussion } }
                        if createDestinations.contains(where: \.canCreateEvent) { Button("Event", systemImage: "calendar.badge.plus") { selectedCreateAction = .event } }
                    }
                }
            }
        }
        .sheet(isPresented: $showingUpdateComposer) {
            SchoologyUpdateComposerView(destinations: postableDestinations) {
                Task {
                    await session.refresh()
                    postableDestinations = await session.loadPostableUpdateDestinations()
                }
            }
        }
        .sheet(item: $selectedCreateAction) { action in
            SchoologyHomeCreateComposerView(destinations: createDestinations, action: action) {
                Task {
                    await session.refresh()
                    postableDestinations = await session.loadPostableUpdateDestinations()
                    createDestinations = await session.loadHomeCreateDestinations()
                }
            }
        }
        .task {
            if !session.hasLoadedHomeActivities || !session.hasLoadedHomeCourses || !session.hasLoadedHomeUpcoming { await session.refresh() }
            async let updateAccess = session.loadPostableUpdateDestinations()
            async let createAccess = session.loadHomeCreateDestinations()
            postableDestinations = await updateAccess
            createDestinations = await createAccess
            #if os(iOS)
            await refreshNotificationPrompt()
            #endif
        }
    }

    @ViewBuilder
    private var notificationPermissionPrompt: some View {
        #if os(iOS)
        if shouldShowNotificationPrompt {
            VStack(alignment: .leading, spacing: 10) {
                Label("Stay up to date", systemImage: "bell.badge").font(.headline)
                Text("Allow Schoology to notify you about new messages, comments, and course activity.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let notificationPromptError {
                    Text(notificationPromptError).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Button("Not Now") {
                        didDismissNotificationPrompt = true
                        shouldShowNotificationPrompt = false
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button("Enable Notifications", systemImage: "bell.badge") {
                        Task { await enableNotifications() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
        }
        #endif
    }

    #if os(iOS)
    private func refreshNotificationPrompt() async {
        guard !didDismissNotificationPrompt else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined {
            shouldShowNotificationPrompt = true
        } else {
            didDismissNotificationPrompt = true
        }
    }

    private func enableNotifications() async {
        notificationPromptError = nil
        do {
            let granted = try await SchoologyPushNotifications.requestAuthorization()
            if granted { await SchoologyPushNotifications.setEnabled(true) }
            didDismissNotificationPrompt = true
            shouldShowNotificationPrompt = false
        } catch {
            notificationPromptError = error.localizedDescription
        }
    }
    #endif

    private var welcomeHeader: some View {
        HStack(spacing: 12) {
            if let user = session.user {
                if let avatar = user.pictureURL {
                    AuthenticatedSchoologyImage(url: avatar).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    SchoologyAvatarPlaceholder(size: 48, tint: SchoologyStyle.blue)
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
                notificationPermissionPrompt
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
    @Environment(AppSession.self) private var session
    let activity: SchoologyActivity
    @ScaledMetric(relativeTo: .body) private var postMinimumFontSize: CGFloat = 15.5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let avatar = activity.avatarURL ?? (activity.authorID == session.auth?.userID ? session.user?.pictureURL : nil) {
                    AuthenticatedSchoologyImage(url: avatar)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Text(SchoologyValue.postDateLabel(date))
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            if !activity.body.isEmpty {
                SchoologyRichTextText(activity.body, minimumFontSize: postMinimumFontSize)
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
                SchoologyAttachmentsButton(attachments: activity.attachments)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        SchoologyAvatarPlaceholder(size: 42, tint: SchoologyStyle.blue)
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

struct UpcomingEventList: View {
    @Environment(AppSession.self) private var session
    let events: [SchoologyUpcomingEvent]
    var isLoading = false
    var errorMessage: String?
    var fallbackRealm: String? = nil
    var fallbackRealmID: String? = nil

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
                                    UpcomingEventDetailView(event: event, fallbackRealm: fallbackRealm, fallbackRealmID: fallbackRealmID)
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
                        NavigationLink(event.title, destination: UpcomingEventDetailView(event: event, fallbackRealm: fallbackRealm, fallbackRealmID: fallbackRealmID))
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
        case "assignment": "pencil.circle.fill"
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

struct UpcomingEventDetailView: View {
    @Environment(AppSession.self) private var session
    let event: SchoologyUpcomingEvent
    var fallbackRealm: String? = nil
    var fallbackRealmID: String? = nil

    @ViewBuilder
    var body: some View {
        switch event.type.lowercased() {
        case "assignment":
            if let sectionID = event.sectionID ?? (eventRealmTarget?.realm == "sections" ? eventRealmTarget?.realmID : nil),
               let assignmentID = event.assignmentID {
                SchoologyAssignmentDetailView(sectionID: sectionID, assignmentID: assignmentID, title: event.title)
            } else {
                unavailableTarget("This assignment is missing its section or assignment identifier.")
            }
        case "discussion":
            if let target = eventRealmTarget,
               ["sections", "groups"].contains(target.realm),
               let discussionID = event.discussionID {
                SchoologyDiscussionDetailView(realm: target.realm, realmID: target.realmID, itemID: discussionID, title: event.title)
            } else if let url = event.webURL {
                SchoologyEmbeddedWebView(url: url, title: event.title)
            } else {
                unavailableTarget("Schoology did not provide a discussion destination.")
            }
        case "event":
            if let target = eventRealmTarget {
                SchoologyEventDetailView(realm: target.realm, realmID: target.realmID, eventID: event.id, title: event.title)
            } else if let url = event.webURL {
                SchoologyEmbeddedWebView(url: url, title: event.title)
            } else {
                unavailableTarget("Schoology did not provide an event destination.")
            }
        case "external_tool", "lti", "lti_assignment":
            if let sectionID = event.sectionID ?? (eventRealmTarget?.realm == "sections" ? eventRealmTarget?.realmID : nil),
               let externalToolID = event.externalToolID {
                SchoologyExternalToolEventView(sectionID: sectionID, documentID: externalToolID, title: event.title)
            } else if let url = event.webURL {
                SchoologyEmbeddedWebView(url: url, title: event.title)
            } else {
                unavailableTarget("Schoology did not provide an external-tool destination.")
            }
        case "assessment", "assessment_v2", "managed_assessment", "quiz":
            if let url = event.webURL {
                SchoologyEmbeddedWebView(url: url, title: event.title)
            } else {
                let host = session.canadianServer ? "app.schoologyca.com" : "app.schoology.com"
                if let url = URL(string: "https://\(host)/assignment/\(event.assignmentID ?? event.id)") {
                    SchoologyEmbeddedWebView(url: url, title: event.title)
                } else {
                    unavailableTarget("Schoology did not provide a quiz destination.")
                }
            }
        default:
            if let url = event.webURL {
                SchoologyEmbeddedWebView(url: url, title: event.title)
            } else {
                unavailableTarget("This upcoming item has no supported destination.")
            }
        }
    }

    private var eventRealmTarget: (realm: String, realmID: String)? {
        if let normalizedRealm = event.realm?.lowercased() {
            switch normalizedRealm {
            case "section", "sections":
                if let id = event.sectionID ?? event.realmID ?? (fallbackRealm == "sections" ? fallbackRealmID : nil) {
                    return ("sections", id)
                }
            case "group", "groups":
                if let id = event.groupID ?? event.realmID ?? (fallbackRealm == "groups" ? fallbackRealmID : nil) {
                    return ("groups", id)
                }
            case "school", "schools":
                if let id = event.schoolID ?? event.realmID ?? (fallbackRealm == "schools" ? fallbackRealmID : nil) {
                    return ("schools", id)
                }
            case "user", "users":
                if let id = event.userID ?? event.realmID ?? session.auth?.userID {
                    return ("users", id)
                }
            default:
                break
            }
        }

        if let sectionID = event.sectionID { return ("sections", sectionID) }
        if let fallbackRealm, let fallbackRealmID {
            switch fallbackRealm.lowercased() {
            case "section", "sections": return ("sections", fallbackRealmID)
            case "group", "groups": return ("groups", fallbackRealmID)
            case "school", "schools": return ("schools", fallbackRealmID)
            case "user", "users": return ("users", fallbackRealmID)
            default: break
            }
        }
        return nil
    }

    private func unavailableTarget(_ message: String) -> some View {
        ContentUnavailableView("Unable to open item", systemImage: "exclamationmark.triangle", description: Text(message))
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
