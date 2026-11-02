import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if session.isSignedIn {
                signedInShell
            } else {
                SignInView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: session.isSignedIn)
    }

    private var signedInShell: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: Binding(
                get: { Optional(session.destination) },
                set: { if let destination = $0 { session.destination = destination } }
            )) {
                Section {
                    ForEach(AppDestination.allCases.filter { $0 != .settings }) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.symbol)
                        }
                    }
                }
                Section {
                    NavigationLink(value: AppDestination.settings) {
                        Label("Settings", systemImage: AppDestination.settings.symbol)
                    }
                }
            }
            .navigationTitle("Schoology")
            .listStyle(.sidebar)
        } detail: {
            DestinationView(destination: session.destination)
        }
        .navigationSplitViewStyle(.balanced)
        #else
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(selection: Binding(
                    get: { Optional(session.destination) },
                    set: { if let destination = $0 { session.destination = destination } }
                )) {
                    ForEach(AppDestination.allCases) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.symbol)
                        }
                    }
                }
                .navigationTitle("Schoology")
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                DestinationView(destination: session.destination)
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            TabView(selection: Binding(
                get: { session.destination },
                set: { session.destination = $0 }
            )) {
                ForEach([AppDestination.home, .courses, .groups, .messages, .notifications, .calendar], id: \.self) { item in
                    Tab(item.rawValue, systemImage: item.symbol, value: item) {
                        NavigationStack {
                            DestinationView(destination: item)
                                .navigationDestination(for: AppDestination.self) {
                                    DestinationView(destination: $0)
                                }
                        }
                    }
                }
                Tab("More", systemImage: "ellipsis", value: AppDestination.settings) {
                    NavigationStack {
                        MoreView()
                            .navigationDestination(for: AppDestination.self) {
                                DestinationView(destination: $0)
                            }
                    }
                }
            }
        }
        #endif
    }
}
