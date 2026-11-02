import SwiftUI

@main
struct SchoologyApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(SchoologyStyle.blue)
                .preferredColorScheme(session.appearance.colorScheme)
        }
        #if os(macOS)
        .commands {
            SchoologyCommands(session: session)
        }
        #endif
    }
}

enum AppDestination: String, CaseIterable, Identifiable {
    case home = "Home"
    case courses = "Courses"
    case groups = "Groups"
    case messages = "Messages"
    case notifications = "Notifications"
    case requests = "Requests"
    case resources = "Resources"
    case grades = "Grades"
    case calendar = "Calendar"
    case people = "People"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .courses: "book.closed.fill"
        case .groups: "person.3.fill"
        case .messages: "envelope.fill"
        case .notifications: "bell.fill"
        case .requests: "person.crop.circle.badge.plus"
        case .resources: "folder.fill"
        case .grades: "chart.bar.fill"
        case .calendar: "calendar"
        case .people: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

enum SchoologyStyle {
    static let blue = Color(red: 0.0, green: 0.39, blue: 0.67)
    static let deepBlue = Color(red: 0.0, green: 0.13, blue: 0.22)
    static let canvas = Color(uiColor: .systemGroupedBackground)
}

#if os(macOS)
import AppKit

struct SchoologyCommands: Commands {
    let session: AppSession

    var body: some Commands {
        SidebarCommands()
        CommandGroup(after: .newItem) {
            Button("Refresh") {
                Task { await session.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
        CommandMenu("Schoology") {
            Button("Home") { session.destination = .home }
                .keyboardShortcut("1", modifiers: .command)
            Button("Courses") { session.destination = .courses }
                .keyboardShortcut("2", modifiers: .command)
            Button("Messages") { session.destination = .messages }
                .keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Sign Out") { session.signOut() }
        }
    }
}
#endif
