import SwiftUI

private enum ClassWireDemoSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case courses = "Courses"
    case upcoming = "Upcoming"
    case grades = "Grades"
    case calendar = "Calendar"
    case messages = "Messages"
    case groups = "Groups"
    case resources = "Resources"
    case profile = "Profile"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .courses: "book.closed.fill"
        case .upcoming: "calendar.badge.clock"
        case .grades: "chart.bar.fill"
        case .calendar: "calendar"
        case .messages: "envelope.fill"
        case .groups: "person.3.fill"
        case .resources: "folder.fill"
        case .profile: "person.crop.square"
        }
    }
}

private struct ClassWireDemoCourse: Identifiable {
    let id: String
    let title: String
    let code: String
    let teacher: String
    let grade: String
}

private struct ClassWireDemoAssignment: Identifiable {
    let id: String
    let title: String
    let course: String
    let due: String
    let status: String
}

private struct ClassWireDemoMessage: Identifiable {
    let id = UUID()
    let sender: String
    let body: String
    let isOutgoing: Bool
}

struct ClassWireDemoView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: ClassWireDemoSection? = .home
    @State private var isLiked = false
    @State private var submittedAssignments: Set<String> = []
    @State private var completedResources: Set<String> = []
    @State private var draftMessage = ""
    @State private var messages = [
        ClassWireDemoMessage(sender: "Jordan Lee", body: "Hi Alex! Are we still meeting to review the biology project?", isOutgoing: false),
        ClassWireDemoMessage(sender: "You", body: "Yes, I’ll bring my notes. See you after class!", isOutgoing: true)
    ]
    @State private var showingDemoInformation = false
    @State private var selectedCourseID = "biology"
    @State private var selectedResource: String?

    private let courses = [
        ClassWireDemoCourse(id: "biology", title: "Biology", code: "BIO-204", teacher: "Ms. Rivera", grade: "A-"),
        ClassWireDemoCourse(id: "algebra", title: "Algebra II", code: "MATH-310", teacher: "Mr. Chen", grade: "B+"),
        ClassWireDemoCourse(id: "history", title: "World History", code: "HIST-112", teacher: "Dr. Patel", grade: "A")
    ]
    private let assignments = [
        ClassWireDemoAssignment(id: "cell-lab", title: "Cell Structure Lab", course: "Biology", due: "Nov 10", status: "Not submitted"),
        ClassWireDemoAssignment(id: "quadratics", title: "Quadratic Functions", course: "Algebra II", due: "Nov 12", status: "In progress"),
        ClassWireDemoAssignment(id: "sources", title: "Primary Source Analysis", course: "World History", due: "Nov 14", status: "Not submitted")
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Learning") {
                    ForEach([ClassWireDemoSection.home, .courses, .upcoming, .grades, .calendar]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                Section("Communication") {
                    ForEach([ClassWireDemoSection.messages, .groups]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                Section("More") {
                    ForEach([ClassWireDemoSection.resources, .profile]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        Label("Exit Demo", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("ClassWire")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            #endif
        } detail: {
            NavigationStack {
                detail
                    .navigationTitle(selection?.rawValue ?? "Home")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Demo information", systemImage: "info.circle") {
                                showingDemoInformation = true
                            }
                        }
                    }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("DEMO MODE").font(.caption.bold())
                Spacer()
                Text("Sample data · Local interactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityElement(children: .combine)
        }
        .alert("About this demo", isPresented: $showingDemoInformation) {
            Button("Continue", role: .cancel) { }
        } message: {
            Text("ClassWire is displaying demonstration data. You can explore the interface and try local interactions, but changes are not sent to Schoology and do not affect real courses, grades, submissions, messages, or user accounts.")
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selection)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .home {
        case .home: home
        case .courses: coursesView
        case .upcoming: upcomingView
        case .grades: gradesView
        case .calendar: calendarView
        case .messages: messagesView
        case .groups: groupsView
        case .resources: resourcesView
        case .profile: profileView
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back").font(.subheadline).foregroundStyle(.secondary)
                    Text("Alex Morgan").font(.largeTitle.bold())
                    Text("Here’s what’s happening with your classes.").foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
                    demoMetric("Courses", value: "3", symbol: "book.closed")
                    demoMetric("Upcoming", value: "3", symbol: "calendar")
                    demoMetric("Average", value: "91.4%", symbol: "chart.bar")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recent activity", systemImage: "text.bubble").font(.headline)
                    demoCard {
                        HStack {
                            SchoologyAvatarPlaceholder(size: 38, tint: SchoologyStyle.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ms. Rivera").font(.subheadline.bold())
                                Text("Biology · 2 hours ago").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Text("Remember to review the cell structure notes before Friday’s lab.")
                        HStack {
                            Button(isLiked ? "Liked" : "Like", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup") { isLiked.toggle() }
                            Spacer()
                            Label("3 comments", systemImage: "bubble.right")
                        }
                        .font(.subheadline)
                    }
                    demoCard {
                        Label("Algebra II", systemImage: "book.closed").font(.subheadline.bold())
                        Text("A new assignment, Quadratic Functions, is due November 12.")
                        Text("Posted yesterday").font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Upcoming assignments", systemImage: "calendar.badge.clock").font(.headline)
                    ForEach(assignments) { assignment in assignmentRow(assignment) }
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private var coursesView: some View {
        List {
            Section("My courses") {
                ForEach(courses) { course in
                    Button {
                        selectedCourseID = course.id
                    } label: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(SchoologyStyle.blue)
                                .frame(width: 38, height: 38)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.title).foregroundStyle(.primary)
                                Text("\(course.code) · \(course.teacher)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(course.grade).font(.headline.monospacedDigit())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if let course = courses.first(where: { $0.id == selectedCourseID }) {
                Section(course.title) {
                    Text("Course overview, materials, updates, grades, members, and course apps are represented in this sample.")
                        .foregroundStyle(.secondary)
                    ForEach(["Overview", "Materials", "Updates", "Grades", "Members", "Course apps"], id: \.self) { item in
                        NavigationLink(item) {
                            List {
                                Text("\(item) for \(course.title)")
                                Text("Representative sample content for App Review.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(assignments.filter { $0.course == course.title }) { assignment in
                        assignmentRow(assignment)
                    }
                }
            }
        }
    }

    private var upcomingView: some View {
        List {
            Section("Due soon") {
                ForEach(assignments) { assignment in assignmentRow(assignment) }
            }
            Section("Events") {
                Label("Biology lab review · Nov 11, 3:30 PM", systemImage: "calendar")
                Label("History study group · Nov 13, 2:45 PM", systemImage: "person.2")
                Label("Algebra tutoring · Nov 15, 4:00 PM", systemImage: "calendar")
            }
        }
    }

    private var gradesView: some View {
        List {
            Section("Overall performance") {
                LabeledContent("Current average", value: "91.4%")
                LabeledContent("Letter grade", value: "A-")
                LabeledContent("Courses with grades", value: "3")
            }
            Section("Course grades") {
                ForEach(courses) { course in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(course.title)
                            Text(course.code).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(course.grade).font(.title3.bold())
                    }
                }
            }
            Section("Biology · Recent grades") {
                LabeledContent("Cell Quiz", value: "18 / 20")
                LabeledContent("Lab Safety", value: "10 / 10")
                LabeledContent("Microscope Notes", value: "24 / 25")
            }
        }
    }

    private var calendarView: some View {
        List {
            Section("November 2026") {
                ForEach([
                    "Nov 10 · Cell Structure Lab due",
                    "Nov 11 · Biology lab review",
                    "Nov 12 · Quadratic Functions due",
                    "Nov 13 · History study group",
                    "Nov 14 · Primary Source Analysis due"
                ], id: \.self) { event in
                    Label(event, systemImage: "calendar")
                }
            }
        }
    }

    private var messagesView: some View {
        VStack(spacing: 0) {
            HStack {
                SchoologyAvatarPlaceholder(size: 40)
                VStack(alignment: .leading) {
                    Text("Jordan Lee").font(.headline)
                    Text("Biology study group").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        HStack {
                            if message.isOutgoing { Spacer(minLength: 45) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.sender).font(.caption.bold()).foregroundStyle(.secondary)
                                Text(message.body)
                            }
                            .padding(12)
                            .background(message.isOutgoing ? SchoologyStyle.blue.opacity(0.14) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                            if !message.isOutgoing { Spacer(minLength: 45) }
                        }
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("Write a demo message", text: $draftMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Send", systemImage: "paperplane.fill") {
                    let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    messages.append(ClassWireDemoMessage(sender: "You", body: text, isOutgoing: true))
                    draftMessage = ""
                }
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    private var groupsView: some View {
        List {
            Section("Groups") {
                Label("Biology Study Group", systemImage: "person.3.fill")
                Label("Class of 2027", systemImage: "person.3.fill")
            }
            Section("Recent group activity") {
                Text("Jordan shared the review guide for Friday’s lab.")
                Text("Avery posted a reminder about the study session.")
                Text("Ms. Rivera shared a new resource.")
            }
            Section("Group sections") {
                ForEach(["Updates", "Members", "Upcoming", "Discussions", "Resources"], id: \.self) { item in
                    NavigationLink(item) {
                        ContentUnavailableView(item, systemImage: "text.bubble", description: Text("Representative demo content for this group section."))
                    }
                }
            }
        }
    }

    private var resourcesView: some View {
        List {
            Section("Biology resources") {
                ForEach(["Unit 3", "Cell Structure Notes.pdf", "Microscope Diagram.png", "Lab Instructions.docx"], id: \.self) { item in
                    Button {
                        selectedResource = item
                    } label: {
                        Label(item, systemImage: item == "Unit 3" ? "folder" : "doc")
                    }
                }
            }
            Section("Selected resource") {
                if let selectedResource {
                    Text(selectedResource).font(.headline)
                    Text("This is a local sample preview. No school file is downloaded.")
                        .foregroundStyle(.secondary)
                    Button(completedResources.contains(selectedResource) ? "Marked as reviewed" : "Mark as reviewed",
                           systemImage: "checkmark.circle") {
                        if completedResources.contains(selectedResource) {
                            completedResources.remove(selectedResource)
                        } else {
                            completedResources.insert(selectedResource)
                        }
                    }
                } else {
                    ContentUnavailableView("Choose a resource", systemImage: "folder")
                }
            }
        }
    }

    private var profileView: some View {
        Form {
            Section("Demo profile") {
                HStack {
                    SchoologyAvatarPlaceholder(size: 64, tint: SchoologyStyle.blue)
                    VStack(alignment: .leading) {
                        Text("Alex Morgan").font(.headline)
                        Text("Student · Sample High School").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Username", value: "tester@classwire.app")
                LabeledContent("Role", value: "Student")
                LabeledContent("School", value: "Sample High School")
            }
            Section("Privacy") {
                Text("All profile details are fictional sample data.")
                Text("No Schoology account or student record is accessed in demo mode.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func demoMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private func demoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private func assignmentRow(_ assignment: ClassWireDemoAssignment) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(assignment.title).font(.headline)
                    Text("\(assignment.course) · Due \(assignment.due)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if submittedAssignments.contains(assignment.id) {
                    Label("Submitted", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                } else {
                    Text(assignment.status).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(submittedAssignments.contains(assignment.id) ? "Undo demo submission" : "Submit sample work",
                   systemImage: "paperplane") {
                if submittedAssignments.contains(assignment.id) {
                    submittedAssignments.remove(assignment.id)
                } else {
                    submittedAssignments.insert(assignment.id)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 5)
    }
}
