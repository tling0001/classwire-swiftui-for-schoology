import SwiftUI

struct SchoologyResourcesView: View {
    @Environment(AppSession.self) private var session
    @State private var expanded: Set<SchoologyResourceCategory> = [.mine, .shared, .groups, .apps]

    var body: some View {
        Group {
            if session.isLoadingResources && !session.hasLoadedResources {
                ProgressView("Loading resources…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.resourcesError, session.resourceCollections.isEmpty && session.resourceApps.isEmpty {
                ContentUnavailableView("Unable to load resources", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List {
                    ForEach(SchoologyResourceCategory.allCases) { category in
                        let items = category == .apps ? session.resourceApps : session.resourceCollections.filter { $0.category == category }
                        Section {
                            if expanded.contains(category) {
                                if items.isEmpty {
                                    Text("No resources").foregroundStyle(.secondary)
                                } else {
                                    ForEach(items) { item in
                                        NavigationLink {
                                            if item.category == .apps {
                                                SchoologyResourceAppLaunchView(app: item)
                                            } else {
                                                SchoologyResourceCollectionView(collection: item)
                                            }
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: item.category == .apps ? "square.grid.2x2" : item.typeID == "3" ? "book.closed" : "folder")
                                                    .font(.title3).foregroundStyle(SchoologyStyle.blue).frame(width: 30)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(item.title).foregroundStyle(.primary)
                                                    if item.sharedCount > 0 {
                                                        Text("\(item.sharedCount) shared with you").font(.caption).foregroundStyle(.secondary)
                                                    }
                                                }
                                            }.padding(.vertical, 3)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Button {
                                if expanded.contains(category) { expanded.remove(category) }
                                else { expanded.insert(category) }
                            } label: {
                                HStack {
                                    Label(category.title, systemImage: category.symbol)
                                    Spacer()
                                    Image(systemName: expanded.contains(category) ? "chevron.down" : "chevron.right")
                                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .schoologyInsetGroupedListStyle()
                .overlay(alignment: .top) {
                    if session.isLoadingResources { ProgressView().padding(.top, 8) }
                }
            }
        }
        .task { await session.loadResources() }
        .refreshable { await session.loadResources(force: true) }
    }
}


private struct SchoologyResourceAppLaunchView: View {
    @Environment(AppSession.self) private var session
    let app: SchoologyResourceCollection
    @State private var launchURL: URL?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let launchURL {
                SchoologyEmbeddedWebView(url: launchURL, title: app.title, requiresWebSession: false)
            } else if loading {
                ProgressView("Opening \\(app.title)…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Unable to open resource app", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            }
        }
        .navigationTitle(app.title)
        .task(id: app.id) {
            loading = true
            error = nil
            do { launchURL = try await session.launchResourceApp(app) }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

private struct SchoologyResourceCollectionView: View {
    @Environment(AppSession.self) private var session
    let collection: SchoologyResourceCollection
    @State private var items: [SchoologyProfileItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView("Loading resources…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, items.isEmpty {
                ContentUnavailableView("Unable to load resources", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView("No resources", systemImage: "folder", description: Text("This collection is empty."))
            } else {
                List(items) { item in
                    SchoologyInlineResourceItemRow(collectionID: collection.id, item: item)
                }
                .schoologyInsetGroupedListStyle()
                .overlay(alignment: .top) { if loading { ProgressView().padding(.top, 8) } }
            }
        }
        .navigationTitle(collection.title)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do { items = try await session.loadResourceItems(collectionID: collection.id, folderID: collection.folderID) }
        catch { self.error = error.localizedDescription }
        loading = false
    }
}

private struct SchoologyInlineResourceItemRow: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let collectionID: String
    let item: SchoologyProfileItem
    @State private var isExpanded = false
    @State private var children: [SchoologyProfileItem]?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        if item.kind.lowercased() == "folder" {
            DisclosureGroup(isExpanded: $isExpanded) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading folder…").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .transition(.opacity)
                } else if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary).padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let children, children.isEmpty {
                    Text("This folder is empty").font(.caption).foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let children {
                    ForEach(children) { child in
                        SchoologyInlineResourceItemRow(collectionID: collectionID, item: child)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } label: {
                Label(item.title, systemImage: "folder").contentShape(Rectangle())
            }
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, children == nil, !isLoading else { return }
                Task { await loadChildren() }
            }
        } else if let url = item.url {
            NavigationLink {
                SchoologyEmbeddedWebView(url: url, title: item.title)
            } label: {
                Label(item.title, systemImage: resourceSymbol)
            }
        } else {
            NavigationLink {
                SchoologyProfileItemDetailSheet(item: item)
            } label: {
                Label(item.title, systemImage: resourceSymbol)
            }
        }
    }

    private var resourceSymbol: String {
        let kind = item.kind.lowercased()
        if kind.contains("link") || item.url?.host != nil { return "link" }
        if kind.contains("page") { return "doc.text" }
        if kind.contains("assessment") || kind.contains("quiz") { return "checklist" }
        if kind.contains("discussion") { return "text.bubble" }
        return "doc"
    }

    @MainActor
    private func loadChildren() async {
        guard !isLoading, children == nil else { return }
        isLoading = true
        loadError = nil
        do {
            let loaded = try await session.loadResourceItems(collectionID: collectionID, folderID: item.id)
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                children = loaded
                isLoading = false
            }
        } catch {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct SchoologyGradesView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedCourses: Set<String> = []
    @State private var gradebooks: [String: SchoologyGradebook] = [:]
    @State private var loadingCourses: Set<String> = []
    @State private var courseErrors: [String: String] = [:]

    var body: some View {
        Group {
            if session.isLoadingUserGrades && !session.hasLoadedUserGrades {
                ProgressView("Loading grades…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.userGradesError, session.userGradeCourses.isEmpty {
                ContentUnavailableView("Unable to load grades", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if session.userGradeCourses.isEmpty {
                ContentUnavailableView("No grades available", systemImage: "chart.bar", description: Text("Course grades will appear here when your instructors publish them."))
            } else {
                List {
                    ForEach(session.userGradeCourses) { course in
                        Section {
                            Button {
                                toggle(course)
                            } label: {
                                HStack(spacing: 12) {
                                    if let image = course.imageURL {
                                        AuthenticatedSchoologyImage(url: image)
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "book.closed.fill")
                                            .font(.title2)
                                            .foregroundStyle(SchoologyStyle.blue)
                                            .frame(width: 48, height: 48)
                                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(course.title).font(.headline).foregroundStyle(.primary)
                                        if course.courseTitle != course.title {
                                            Text(course.courseTitle).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(SchoologyGradeValueFormatter.display(course.overallGrade)).font(.headline.monospacedDigit()).foregroundStyle(.primary)
                                    Image(systemName: expandedCourses.contains(course.id) ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(course.title), overall grade \(SchoologyGradeValueFormatter.display(course.overallGrade))")
                            .accessibilityHint(expandedCourses.contains(course.id) ? "Collapse course grades" : "Show grading periods, categories, and assignments")

                            if expandedCourses.contains(course.id) {
                                if loadingCourses.contains(course.id) {
                                    ProgressView("Loading course grades…").frame(maxWidth: .infinity).padding()
                                } else if let error = courseErrors[course.id] {
                                    ContentUnavailableView("Unable to load course grades", systemImage: "exclamationmark.triangle", description: Text(error))
                                } else if let gradebook = gradebooks[course.id] {
                                    SchoologyGradebookView(gradebook: gradebook)
                                        .listRowInsets(EdgeInsets())
                                }
                            }
                        }
                    }
                }
                .schoologyInsetGroupedListStyle()
            }
        }
        .task { await session.loadUserGradeCourses() }
        .refreshable { await refresh() }
    }

    private func toggle(_ course: SchoologyUserGradeCourse) {
        let shouldExpand = !expandedCourses.contains(course.id)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            if shouldExpand { expandedCourses.insert(course.id) }
            else { expandedCourses.remove(course.id) }
        }
        guard shouldExpand, gradebooks[course.id] == nil, !loadingCourses.contains(course.id) else { return }
        Task { await loadGrades(for: course) }
    }

    private func loadGrades(for course: SchoologyUserGradeCourse) async {
        loadingCourses.insert(course.id)
        courseErrors[course.id] = nil
        do { gradebooks[course.id] = try await session.loadCourseGradebook(courseID: course.id) }
        catch { courseErrors[course.id] = error.localizedDescription }
        loadingCourses.remove(course.id)
    }

    private func refresh() async {
        await session.loadUserGradeCourses(force: true)
        for course in session.userGradeCourses where expandedCourses.contains(course.id) {
            await loadGrades(for: course)
        }
    }
}

private struct SchoologyCalendarDayCell: Identifiable {
    let id: String
    let date: Date?
}

struct SchoologyCalendarView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode = "calendar"
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = Calendar.current.veryShortWeekdaySymbols

    private var monthDays: [SchoologyCalendarDayCell] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth),
              let first = Calendar.current.dateInterval(of: .month, for: displayedMonth)?.start else { return [] }
        let offset = Calendar.current.component(.weekday, from: first) - 1
        let count = ((offset + range.count + 6) / 7) * 7
        let monthKey = String(displayedMonth.formatted(.dateTime.year().month()))
        return (0..<count).map { slot in
            let day = slot - offset + 1
            let date = day >= 1 && day <= range.count ? Calendar.current.date(byAdding: .day, value: day - 1, to: first) : nil
            return SchoologyCalendarDayCell(id: "\(monthKey)-slot-\(slot)", date: date)
        }
    }

    private var selectedEvents: [SchoologyUpcomingEvent] {
        session.calendarMonthEvents.filter { event in
            guard let date = event.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDate)
        }.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Calendar view", selection: $mode) {
                Text("Calendar").tag("calendar")
                Text("Upcoming").tag("upcoming")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 10)
            if mode == "calendar" { calendarContent } else { upcomingContent }
        }
        .navigationTitle("Calendar")
        .task {
            await session.loadCalendarUpcoming()
            await session.loadCalendarMonth(displayedMonth)
        }
        .refreshable {
            if mode == "calendar" { await session.loadCalendarMonth(displayedMonth, force: true) }
            else { await session.loadCalendarUpcoming(force: true) }
        }
    }

    private var calendarContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button("Previous month", systemImage: "chevron.left") { changeMonth(-1) }.labelStyle(.iconOnly)
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button("Next month", systemImage: "chevron.right") { changeMonth(1) }.labelStyle(.iconOnly)
                }.buttonStyle(.bordered)
                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(monthDays) { cell in
                        if let day = cell.date {
                            let events = session.calendarMonthEvents.filter { $0.date.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false }
                            Button {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) { selectedDate = day }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(day.formatted(.dateTime.day())).font(.body.monospacedDigit())
                                    Circle().fill(events.isEmpty ? Color.clear : SchoologyStyle.blue).frame(width: 5, height: 5)
                                }
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .background(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? SchoologyStyle.blue.opacity(0.15) : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (events.isEmpty ? "" : ", \(events.count) events"))
                            .accessibilityAddTraits(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? .isSelected : [])
                        } else {
                            Color.clear.frame(height: 42)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted)).font(.headline)
                    if session.isLoadingCalendar && session.calendarMonthEvents.isEmpty {
                        ProgressView("Loading calendar…")
                    } else if let error = session.calendarError, session.calendarMonthEvents.isEmpty {
                        ContentUnavailableView("Unable to load calendar", systemImage: "exclamationmark.triangle", description: Text(error))
                    } else if selectedEvents.isEmpty {
                        ContentUnavailableView("No events on this date", systemImage: "calendar")
                    } else {
                        ForEach(selectedEvents) { event in SchoologyCalendarEventRow(event: event) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private var upcomingContent: some View {
        ScrollView {
            UpcomingEventList(
                events: session.calendarUpcomingEvents,
                isLoading: session.isLoadingCalendar,
                errorMessage: session.calendarError
            )
            .padding()
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }

    private func changeMonth(_ offset: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            displayedMonth = next
            if !Calendar.current.isDate(next, equalTo: selectedDate, toGranularity: .month) { selectedDate = next }
        }
        Task { await session.loadCalendarMonth(next) }
    }
}

private struct SchoologyCalendarEventRow: View {
    @Environment(AppSession.self) private var session
    let event: SchoologyUpcomingEvent

    var body: some View {
        Group {
            if event.type == "assignment", let assignmentID = event.assignmentID, let sectionID = event.sectionID {
                NavigationLink {
                    SchoologyAssignmentDetailView(sectionID: sectionID, assignmentID: assignmentID, title: event.title)
                } label: { rowContent }
            } else if event.type == "discussion" {
                NavigationLink {
                    SchoologyDiscussionDetailView(realm: event.sectionID == nil ? "users" : "sections",
                        realmID: event.sectionID ?? session.auth?.userID ?? "", itemID: event.discussionID ?? event.id, title: event.title)
                } label: { rowContent }
            } else {
                NavigationLink {
                    SchoologyEventDetailView(realm: event.sectionID == nil ? "users" : "sections",
                        realmID: event.sectionID ?? session.auth?.userID ?? "", eventID: event.id, title: event.title)
                } label: { rowContent }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(SchoologyStyle.blue).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).foregroundStyle(.primary)
                Text(event.typeLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let date = event.date { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption) }
                if !event.timeLabel.isEmpty { Text(event.timeLabel).font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 4)
    }

    private var icon: String {
        switch event.type {
        case "assignment": "doc.text"
        case "discussion": "text.bubble"
        case "assessment", "assessment_v2", "managed_assessment", "quiz": "checklist"
        default: "calendar"
        }
    }
}
