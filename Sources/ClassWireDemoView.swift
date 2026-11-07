import SwiftUI

private enum ClassWireDemoSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case courses = "Courses"
    case upcoming = "Upcoming"
    case assignments = "Assignments"
    case grades = "Grades"
    case calendar = "Calendar"
    case messages = "Messages"
    case notifications = "Notifications"
    case groups = "Groups"
    case people = "People"
    case requests = "Requests"
    case resources = "Resources"
    case profile = "Profile"
    case settings = "Settings"
    case teacherTools = "Teacher tools"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .courses: "book.closed.fill"
        case .upcoming: "calendar.badge.clock"
        case .assignments: "doc.text"
        case .grades: "chart.bar.fill"
        case .calendar: "calendar"
        case .messages: "envelope.fill"
        case .notifications: "bell.fill"
        case .groups: "person.3.fill"
        case .people: "person.2.fill"
        case .requests: "person.crop.circle.badge.plus"
        case .resources: "folder.fill"
        case .profile: "person.crop.square"
        case .settings: "gearshape.fill"
        case .teacherTools: "person.crop.rectangle.stack"
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
    @State private var selectedAssignment: ClassWireDemoAssignment?
    @State private var selectedResource: String?
    @State private var showingResourcePreview = false
    @State private var showingPostDiscussion = false
    @State private var notificationReadIDs: Set<String> = []
    @State private var dismissedRequestIDs: Set<String> = []
    @State private var acceptedRequestIDs: Set<String> = []
    @State private var demoNotificationsEnabled = true
    @State private var demoAppearance = "System"
    @State private var demoRole = "Student"
    @State private var demoGrade = "18"
    @State private var demoGradeSaved = false
    @State private var messageHasSampleAttachment = false

    private let courses = [
        ClassWireDemoCourse(id: "biology", title: "Biology", code: "BIO-204", teacher: "Ms. Rivera", grade: "A-"),
        ClassWireDemoCourse(id: "algebra", title: "Algebra II", code: "MATH-310", teacher: "Mr. Chen", grade: "B+"),
        ClassWireDemoCourse(id: "history", title: "World History", code: "HIST-112", teacher: "Dr. Patel", grade: "A")
    ]
    private let assignments = [
        ClassWireDemoAssignment(id: "cell-lab", title: "Cell Structure Lab", course: "Biology", due: "Nov 10", status: "Not submitted", isExternalTool: false),
        ClassWireDemoAssignment(id: "quadratics", title: "Quadratic Functions", course: "Algebra II", due: "Nov 12", status: "In progress", isExternalTool: false),
        ClassWireDemoAssignment(id: "sources", title: "Primary Source Analysis", course: "World History", due: "Nov 14", status: "Not submitted", isExternalTool: false),
        ClassWireDemoAssignment(id: "virtual-lab", title: "Virtual Lab Simulation", course: "Biology", due: "Nov 16", status: "External tool", isExternalTool: true)
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Learning") {
                    ForEach([ClassWireDemoSection.home, .courses, .upcoming, .assignments, .grades, .calendar]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                Section("Communication") {
                    ForEach([ClassWireDemoSection.messages, .notifications, .groups, .people, .requests]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                Section("More") {
                    ForEach([ClassWireDemoSection.resources, .profile, .settings]) { item in
                        Label(item.rawValue, systemImage: item.symbol).tag(item)
                    }
                }
                if demoRole == "Teacher" {
                    Section("Teaching") {
                        Label(ClassWireDemoSection.teacherTools.rawValue, systemImage: ClassWireDemoSection.teacherTools.symbol)
                            .tag(ClassWireDemoSection.teacherTools)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        session.exitDemoMode()
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
        .onChange(of: demoRole) { _, role in
            if role != "Teacher" && selection == .teacherTools { selection = .settings }
        }
        .sheet(item: $selectedAssignment) { assignment in
            ClassWireDemoAssignmentDetailView(
                assignment: assignment,
                isTeacher: demoRole == "Teacher",
                isSubmitted: Binding(
                    get: { submittedAssignments.contains(assignment.id) },
                    set: { submitted in
                        if submitted { submittedAssignments.insert(assignment.id) }
                        else { submittedAssignments.remove(assignment.id) }
                    }
                )
            )
        }
        .sheet(isPresented: $showingPostDiscussion) {
            ClassWireDemoPostDetailView(isLiked: $isLiked)
        }
        .sheet(isPresented: $showingResourcePreview) {
            if let selectedResource {
                ClassWireDemoResourcePreviewView(resourceName: selectedResource)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .home {
        case .home: home
        case .courses: coursesView
        case .upcoming: upcomingView
        case .assignments: assignmentsView
        case .grades: gradesView
        case .calendar: calendarView
        case .messages: messagesView
        case .notifications: notificationsView
        case .groups: groupsView
        case .people: peopleView
        case .requests: requestsView
        case .resources: resourcesView
        case .profile: profileView
        case .settings: settingsView
        case .teacherTools: teacherToolsView
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
                            Button("3 comments", systemImage: "bubble.right") {
                                showingPostDiscussion = true
                            }
                            }
                        .font(.subheadline)
                        Button("View post and comments", systemImage: "arrow.up.right") {
                            showingPostDiscussion = true
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
                            courseSectionDetail(item, course: course)
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
                NavigationLink("Biology lab review · Nov 11, 3:30 PM") {
                    eventDetail("Biology lab review", date: "November 11, 3:30 PM", location: "Biology classroom")
                }
                NavigationLink("History study group · Nov 13, 2:45 PM") {
                    eventDetail("History study group", date: "November 13, 2:45 PM", location: "Library")
                }
                NavigationLink("Algebra tutoring · Nov 15, 4:00 PM") {
                    eventDetail("Algebra tutoring", date: "November 15, 4:00 PM", location: "Room 214")
                }
            }
        }
    }

    private var assignmentsView: some View {
        List {
            Section("Current assignments") {
                ForEach(assignments) { assignment in assignmentRow(assignment) }
            }
            Section("About external-tool activities") {
                Text("Activities launched through an LTI or other external learning tool are opened in that provider. They do not use ClassWire's normal text/file submission composer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notificationsView: some View {
        List {
            Section {
                ForEach([
                    "comment|Ms. Rivera commented on your Biology update|Biology · 20 minutes ago",
                    "assignment|Quadratic Functions is due soon|Algebra II · 1 hour ago",
                    "grade|A new grade was posted for Cell Quiz|Biology · Yesterday",
                    "message|Jordan Lee sent you a message|Messages · Yesterday"
                ], id: \.self) { entry in
                    let fields = entry.split(separator: "|", maxSplits: 2).map(String.init)
                    Button {
                        notificationReadIDs.insert(fields[0])
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: fields[0] == "message" ? "envelope" : "bell")
                                .foregroundStyle(SchoologyStyle.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fields[1]).foregroundStyle(.primary)
                                Text(fields[2]).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !notificationReadIDs.contains(fields[0]) {
                                Circle().fill(SchoologyStyle.blue).frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Recent notifications")
                    Spacer()
                    Button("Mark all read") { notificationReadIDs = ["comment", "assignment", "grade", "message"] }
                        .font(.caption)
                }
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
                NavigationLink("Nov 10 · Cell Structure Lab due") {
                    eventDetail("Cell Structure Lab", date: "November 10", location: "Biology")
                }
                NavigationLink("Nov 11 · Biology lab review") {
                    eventDetail("Biology lab review", date: "November 11, 3:30 PM", location: "Biology classroom")
                }
                NavigationLink("Nov 12 · Quadratic Functions due") {
                    eventDetail("Quadratic Functions", date: "November 12", location: "Algebra II")
                }
                NavigationLink("Nov 13 · History study group") {
                    eventDetail("History study group", date: "November 13, 2:45 PM", location: "Library")
                }
                NavigationLink("Nov 14 · Primary Source Analysis due") {
                    eventDetail("Primary Source Analysis", date: "November 14", location: "World History")
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
                Button("Attach", systemImage: "paperclip") {
                    messageHasSampleAttachment = true
                }
                .labelStyle(.iconOnly)
                Button("Send", systemImage: "paperplane.fill") {
                    let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty || messageHasSampleAttachment else { return }
                    let body = [text, messageHasSampleAttachment ? "Attachment: Biology review.pdf" : ""].filter { !$0.isEmpty }.joined(separator: "\n")
                    messages.append(ClassWireDemoMessage(sender: "You", body: body, isOutgoing: true))
                    draftMessage = ""
                    messageHasSampleAttachment = false
                }
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !messageHasSampleAttachment)
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
                        groupSectionDetail(item)
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
                        showingResourcePreview = true
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

    private var peopleView: some View {
        List {
            Section("Course members") {
                ForEach(["Jordan Lee", "Avery Johnson", "Taylor Brooks", "Ms. Rivera"], id: \.self) { person in
                    NavigationLink {
                        Form {
                            Section("Profile") {
                                HStack {
                                    SchoologyAvatarPlaceholder(size: 56, tint: SchoologyStyle.blue)
                                    VStack(alignment: .leading) {
                                        Text(person).font(.headline)
                                        Text(person == "Ms. Rivera" ? "Teacher" : "Student").foregroundStyle(.secondary)
                                    }
                                }
                                LabeledContent("School", value: "Sample High School")
                                LabeledContent("Course", value: "Biology")
                            }
                            Section("About") {
                                Text("This is fictional profile information included for demonstration.")
                            }
                        }
                        .navigationTitle(person)
                    } label: {
                        Label(person, systemImage: "person.crop.square")
                    }
                }
            }
        }
    }

    private var requestsView: some View {
        List {
            Section("Pending requests") {
                ForEach(["Biology Study Group", "Class of 2027"], id: \.self) { request in
                    if !dismissedRequestIDs.contains(request) && !acceptedRequestIDs.contains(request) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(request, systemImage: "person.3")
                                .font(.headline)
                            Text("Invitation to join this Schoology group.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Accept") { acceptedRequestIDs.insert(request) }
                                    .buttonStyle(.borderedProminent)
                                Button("Decline", role: .destructive) { dismissedRequestIDs.insert(request) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if !acceptedRequestIDs.isEmpty {
                Section("Accepted") {
                    ForEach(Array(acceptedRequestIDs).sorted(), id: \.self) { Text($0) }
                }
            }
        }
    }

    private var settingsView: some View {
        Form {
            Section("Demo account type") {
                Picker("Role", selection: $demoRole) {
                    Text("Student").tag("Student")
                    Text("Teacher").tag("Teacher")
                }
                .pickerStyle(.segmented)
                Text("Switch between fictional student and teacher views to explore both sets of workflows.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Theme", selection: $demoAppearance) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
                Text("This preference is simulated locally and does not change the device or production app settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("Demo notifications", isOn: $demoNotificationsEnabled)
                Text("This toggle only changes the sample notification experience. No APNs registration is made.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy and account") {
                Text("Demo mode uses fictional sample data and does not authenticate with Schoology.")
                Text("No changes are sent to Schoology. Exit Demo returns to the sign-in screen or restores a previously saved account.")
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("App", value: "ClassWire")
                LabeledContent("Build", value: AppVersion.current)
            }
        }
    }

    private var teacherToolsView: some View {
        Form {
            Section("Teacher gradebook") {
                ForEach(courses) { course in
                    LabeledContent(course.title, value: course.grade)
                }
            }
            Section("Student submissions") {
                ForEach(assignments.filter { !$0.isExternalTool }) { assignment in
                    Button {
                        selectedAssignment = assignment
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(assignment.title)
                                Text(assignment.course).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Review").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Quick grade entry") {
                LabeledContent("Student", value: "Jordan Lee")
                TextField("Score", text: $demoGrade)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Button("Save sample grade", systemImage: "checkmark") { demoGradeSaved = true }
                if demoGradeSaved {
                    Label("Grade saved locally: \(demoGrade) / 20", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Text("This gradebook and grade editor are simulations. No student grade is changed in Schoology.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Course management") {
                Label("Course updates", systemImage: "text.bubble")
                Label("Members and enrollments", systemImage: "person.2")
                Label("Connected learning tools", systemImage: "app.connected.to.app.below.fill")
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
                        Text("\(demoRole) · Sample High School").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Username", value: "tester@classwire.app")
                LabeledContent("Role", value: demoRole)
                LabeledContent("School", value: "Sample High School")
            }
            Section("Privacy") {
                Text("All profile details are fictional sample data.")
                Text("No Schoology account or student record is accessed in demo mode.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func courseSectionDetail(_ section: String, course: ClassWireDemoCourse) -> some View {
        List {
            Section(course.title) {
                Text(section == "Overview" ? "Welcome to \(course.title). This sample course includes announcements, learning materials, assignments, grades, and class members." : "\(section) for \(course.title)")
                    .foregroundStyle(.secondary)
            }
            switch section {
            case "Materials":
                Section("Folders and files") {
                    Label("Unit 1 · Foundations", systemImage: "folder")
                    Label("Unit 2 · Current unit", systemImage: "folder")
                    Label("Lecture notes.pdf", systemImage: "doc.richtext")
                    Label("Class presentation.pptx", systemImage: "doc")
                    Label("Lab demonstration.mp4", systemImage: "play.rectangle")
                }
            case "Updates":
                Section("Recent updates") {
                    Text("Ms. Rivera: Please review the study guide before the next class.")
                    Text("Jordan Lee: Shared notes from today's lesson.")
                }
            case "Grades":
                Section("Grade summary") {
                    LabeledContent("Current grade", value: course.grade)
                    LabeledContent("Graded activities", value: "8")
                    LabeledContent("Missing work", value: "0")
                }
            case "Members":
                Section("People") {
                    ForEach(["Ms. Rivera", "Jordan Lee", "Avery Johnson", "Taylor Brooks"], id: \.self) { Text($0) }
                }
            case "Course apps":
                Section("Connected learning tools") {
                    Label("Virtual Lab", systemImage: "app.connected.to.app.below.fill")
                    Label("Class Presentation", systemImage: "rectangle.on.rectangle")
                    Text("External tools open in their provider and may have separate privacy terms.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            default:
                Section("Assignments") {
                    ForEach(assignments.filter { $0.course == course.title }) { assignment in
                        Button(assignment.title) { selectedAssignment = assignment }
                    }
                }
            }
        }
        .navigationTitle(section)
    }

    @ViewBuilder
    private func groupSectionDetail(_ section: String) -> some View {
        List {
            Section("Biology Study Group") {
                Text("A collaborative group for sharing study materials and coordinating class activities.")
                    .foregroundStyle(.secondary)
            }
            switch section {
            case "Members":
                Section("Members") {
                    ForEach(["Jordan Lee", "Avery Johnson", "Taylor Brooks", "Ms. Rivera"], id: \.self) { Text($0) }
                }
            case "Upcoming":
                Section("Events") {
                    Text("Study session · November 13, 2:45 PM")
                    Text("Project review · November 17, 3:30 PM")
                }
            case "Discussions":
                Section("Discussions") {
                    Text("What should we focus on for the cell structure quiz?")
                    Text("I uploaded my notes from the lab.")
                    Text("Who can join the review session?")
                }
            case "Resources":
                Section("Shared resources") {
                    Label("Biology review guide.pdf", systemImage: "doc.richtext")
                    Label("Cell diagram.png", systemImage: "photo")
                    Label("Study notes", systemImage: "folder")
                }
            default:
                Section("Updates") {
                    Text("Jordan shared the review guide for Friday's lab.")
                    Text("Avery posted a reminder about the study session.")
                    Text("Ms. Rivera shared a new resource.")
                }
            }
        }
        .navigationTitle(section)
    }

    private func eventDetail(_ title: String, date: String, location: String) -> some View {
        Form {
            Section("Event") {
                Text(title).font(.headline)
                LabeledContent("When", value: date)
                LabeledContent("Location", value: location)
                LabeledContent("Calendar", value: "Sample High School")
            }
            Section("Details") {
                Text("This event is fictional sample content. Reminders and calendar changes are not sent to Schoology.")
            }
        }
        .navigationTitle("Event")
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
            Button {
                selectedAssignment = assignment
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(assignment.title).font(.headline)
                        Text("\(assignment.course) · Due \(assignment.due)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if submittedAssignments.contains(assignment.id) {
                        Label("Submitted", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    } else {
                        Text(assignment.status).font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if assignment.isExternalTool {
                Label("External learning tool · no native submission composer", systemImage: "app.connected.to.app.below.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else if demoRole == "Teacher" {
                Button("Review sample submissions", systemImage: "doc.text.magnifyingglass") {
                    selectedAssignment = assignment
                }
                .font(.subheadline)
            } else {
                Button(submittedAssignments.contains(assignment.id) ? "Undo sample submission" : "Record sample submission",
                       systemImage: "paperplane") {
                    if submittedAssignments.contains(assignment.id) {
                        submittedAssignments.remove(assignment.id)
                    } else {
                        submittedAssignments.insert(assignment.id)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 5)
    }
}
