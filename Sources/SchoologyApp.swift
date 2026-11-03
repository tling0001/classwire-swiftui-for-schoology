import SwiftUI

@main
struct SchoologyApp: App {
    @State private var session = AppSession()
    @State private var updateService = AppUpdateService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(updateService)
                .task { await updateService.checkForUpdates() }
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
    case profile = "Profile"
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
        case .profile: "person.crop.circle"
        case .settings: "gearshape.fill"
        }
    }
}

enum SchoologyStyle {
    static let blue = Color(red: 0.0, green: 0.39, blue: 0.67)
    static let deepBlue = Color(red: 0.0, green: 0.13, blue: 0.22)
}

struct SchoologyNavigationTabPickerModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            content.pickerStyle(.tabs)
        } else {
            content.pickerStyle(.segmented)
        }
        #else
        content.pickerStyle(.segmented)
        #endif
    }
}

struct SchoologyGlassSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
        #elseif os(iOS)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
        #endif
    }
}

extension View {
    func schoologyNavigationTabPickerStyle() -> some View {
        modifier(SchoologyNavigationTabPickerModifier())
    }

    func schoologyGlassSurface() -> some View {
        modifier(SchoologyGlassSurfaceModifier())
    }
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
