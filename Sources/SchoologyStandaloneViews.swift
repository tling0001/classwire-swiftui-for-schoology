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
        SchoologyResourcesContentView(
            items: items,
            source: .collection(collectionID: collection.id),
            isLoading: loading,
            error: error,
            emptyTitle: "No resources",
            emptyDescription: "This collection is empty."
        ) {
            await load()
        }
        .navigationTitle(collection.title)
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do { items = try await session.loadResourceItems(collectionID: collection.id, folderID: collection.folderID) }
        catch { self.error = error.localizedDescription }
        loading = false
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
        GeometryReader { proxy in
            if proxy.size.width >= 801 {
                let splitWidth = max(0, proxy.size.width - 1)
                HStack(spacing: 0) {
                    ScrollView {
                        monthCalendarContent
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(width: splitWidth * 0.4).frame(maxHeight: .infinity)

                    Divider()

                    ScrollView {
                        selectedDayContent
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(width: splitWidth * 0.6).frame(maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        monthCalendarContent
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        Divider()
                        selectedDayContent
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var monthCalendarContent: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Previous month", systemImage: "chevron.left") { changeMonth(-1) }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button("Next month", systemImage: "chevron.right") { changeMonth(1) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)

            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(monthDays) { cell in
                    if let day = cell.date {
                        let dayEvents = events(on: day)
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                                selectedDate = day
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(day.formatted(.dateTime.day()))
                                    .font(.body.monospacedDigit())
                                Circle()
                                    .fill(dayEvents.isEmpty ? Color.clear : SchoologyStyle.blue)
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Calendar.current.isDate(day, inSameDayAs: selectedDate)
                                    ? SchoologyStyle.blue.opacity(0.15) : .clear,
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            day.formatted(date: .complete, time: .omitted) +
                            (dayEvents.isEmpty ? "" : ", \(dayEvents.count) events")
                        )
                        .accessibilityAddTraits(
                            Calendar.current.isDate(day, inSameDayAs: selectedDate) ? .isSelected : []
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private var selectedDayContent: some View {
        UpcomingEventList(
            events: selectedEvents,
            isLoading: session.isLoadingCalendar && session.calendarMonthEvents.isEmpty,
            errorMessage: session.calendarError
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func events(on day: Date) -> [SchoologyUpcomingEvent] {
        session.calendarMonthEvents.filter { event in
            guard let date = event.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: day)
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

