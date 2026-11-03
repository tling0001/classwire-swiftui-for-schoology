import SwiftUI

struct MessagesView: View {
    @Environment(AppSession.self) private var session
    @State private var folder: SchoologyMessageFolder = .inbox
    @State private var messages: [SchoologyMessage] = []
    @State private var selectedMessage: SchoologyMessage?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 760 {
                HStack(spacing: 0) {
                    messageList
                        .frame(width: min(340, max(270, geometry.size.width * 0.34)))
                    Divider()
                    Group {
                        if let selectedMessage {
                            MessageThreadView(message: selectedMessage, folder: folder)
                                .id(selectedMessage.id + folder.rawValue)
                        } else {
                            ContentUnavailableView("Select a message", systemImage: "envelope", description: Text("Choose a message to read its conversation."))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                NavigationStack {
                    messageList
                        .navigationDestination(item: $selectedMessage) { message in
                            MessageThreadView(message: message, folder: folder)
                        }
                }
            }
        }
        .task(id: folder) { await loadFolder() }
    }

    private var messageList: some View {
        VStack(spacing: 0) {
            Picker("Message folder", selection: $folder) {
                ForEach(SchoologyMessageFolder.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .schoologyNavigationTabPickerStyle()
            .padding(.horizontal)
            .padding(.vertical, 10)

            if isLoading && messages.isEmpty {
                ProgressView("Loading messages…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, messages.isEmpty {
                ContentUnavailableView("Unable to load messages", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if messages.isEmpty {
                ContentUnavailableView("No messages", systemImage: "envelope", description: Text(folder == .unread ? "Your inbox has no unread messages." : "Messages will appear here."))
            } else {
                List(messages) { message in
                    if folder == .unread || folder == .inbox {
                        Button { selectedMessage = message } label: { messageRow(message) }
                            .buttonStyle(.plain)
                    } else {
                        Button { selectedMessage = message } label: { messageRow(message) }
                            .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadFolder(force: true) }
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await loadFolder(force: true) }
                }
                .disabled(isLoading)
            }
        }
    }

    private func messageRow(_ message: SchoologyMessage) -> some View {
        HStack(spacing: 11) {
            if let url = message.personPictureURL {
                AuthenticatedSchoologyImage(url: url)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(SchoologyStyle.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.personName.isEmpty ? "Schoology" : message.personName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let date = SchoologyValue.date(message.created) {
                        Text(date, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Text(message.subject).font(.subheadline.weight(message.isUnread ? .bold : .medium)).lineLimit(1)
                if !message.body.isEmpty {
                    Text(message.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            if message.isUnread {
                Circle().fill(SchoologyStyle.blue).frame(width: 8, height: 8)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func loadFolder(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        let result = await session.loadMessages(folder: folder, force: force)
        messages = result
        loadError = session.errorMessage
        isLoading = false
        if let selectedMessage, !result.contains(where: { $0.id == selectedMessage.id }) {
            self.selectedMessage = nil
        }
    }
}

private struct MessageThreadView: View {
    @Environment(AppSession.self) private var session
    let message: SchoologyMessage
    let folder: SchoologyMessageFolder
    @State private var thread: [SchoologyMessage] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading conversation…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Unable to load message", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(thread) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    if let avatar = item.personPictureURL {
                                        AuthenticatedSchoologyImage(url: avatar)
                                            .frame(width: 38, height: 38)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(SchoologyStyle.blue)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.personName.isEmpty ? "Schoology" : item.personName)
                                            .font(.subheadline.weight(.semibold))
                                        if let date = SchoologyValue.date(item.created) {
                                            Text(date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                Text(item.body.isEmpty ? " " : item.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                ForEach(item.attachments) { attachment in
                                    Link(destination: attachment.url) {
                                        Label(attachment.title, systemImage: "paperclip")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(15)
                            .background(.background, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
                        }
                    }
                    .padding()
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(message.subject)
        .task(id: message.id) {
            isLoading = true
            let loaded = await session.loadMessageThread(message, folder: folder)
            thread = loaded
            error = loaded.isEmpty ? (session.errorMessage ?? "No conversation content was returned.") : nil
            isLoading = false
        }
    }
}

struct NotificationsView: View {
    @Environment(AppSession.self) private var session
    @State private var notifications: [SchoologyNotification] = []
    @State private var isLoading = false

    var body: some View {
        List(notifications) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    if let date = SchoologyValue.date(item.created) {
                        Text(date, style: .relative).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                if !item.body.isEmpty {
                    Text(item.body).font(.body).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
        }
        .overlay {
            if isLoading && notifications.isEmpty {
                ProgressView("Loading notifications…")
            } else if notifications.isEmpty {
                ContentUnavailableView("No notifications", systemImage: "bell", description: Text("New Schoology notifications will appear here."))
            }
        }
        .navigationTitle("Notifications")
        .refreshable { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                    .disabled(isLoading)
            }
        }
        .task { if notifications.isEmpty { await load() } }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        notifications = await session.loadNotifications()
        isLoading = false
    }
}

struct SignedInProfileView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    if let picture = session.user?.pictureURL {
                        AuthenticatedSchoologyImage(url: picture)
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(SchoologyStyle.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.user?.nameDisplay ?? "Schoology user")
                            .font(.title3.weight(.semibold))
                        Text("Signed in account").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Account") {
                LabeledContent("Name", value: session.user?.nameDisplay ?? "—")
                LabeledContent("User ID", value: session.user?.id ?? "—")
            }
            Section {
                Button("Sign Out", role: .destructive) { session.signOut() }
            }
        }
        .navigationTitle("Profile")
    }
}
