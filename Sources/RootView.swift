import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        Group {
            if session.isSignedIn {
                NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
                    SchoologySidebar()
                } detail: {
                    NavigationStack {
                        DestinationView(destination: session.destination)
                    }
                    // Each sidebar destination owns a fresh detail stack. Deeper
                    // course, group, assignment, and profile links then push instead
                    // of replacing the split view's root detail content.
                    .id(session.destination)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                SignInView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: session.isSignedIn)
    }
}

private struct SchoologySidebar: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            #if os(macOS)
            List(selection: Binding<AppDestination?>(
                get: { session.destination },
                set: { if let destination = $0 { session.destination = destination } }
            )) {
                sidebarSections
            }
            #else
            List(selection: Binding<AppDestination?>(
                get: { session.destination },
                set: { if let destination = $0 { session.destination = destination } }
            )) {
                sidebarSections
            }
            #endif
        }
        .navigationTitle("Schoology")
        .listStyle(.sidebar)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var sidebarSections: some View {
        Section("Learning") {
            ForEach([AppDestination.home, .courses, .groups, .calendar]) { item in
                destinationRow(item)
            }
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
        NavigationLink(value: item) {
            Label(item.rawValue, systemImage: item.symbol)
        }
        #else
        NavigationLink(value: item) {
            Label(item.rawValue, systemImage: item.symbol)
        }
        #endif
    }
}
