import SwiftUI

struct MessagesView: View {
    @Environment(AppSession.self) private var session
    @State private var folder: SchoologyMessageFolder = .inbox
    @State private var messages: [SchoologyMessage] = []
    @State private var selectedMessage: SchoologyMessage?
    @State private var loadingFolder: SchoologyMessageFolder?
    @State private var loadError: String?

    private var isLoading: Bool { loadingFolder == folder }
    @State private var showingComposer = false

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
                messageList
                    .navigationDestination(item: $selectedMessage) { message in
                        MessageThreadView(message: message, folder: folder)
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

            if messages.isEmpty {
                if isLoading {
                    ProgressView("Loading messages…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    ContentUnavailableView("Unable to load messages", systemImage: "exclamationmark.triangle", description: Text(loadError))
                } else {
                    ContentUnavailableView("No messages", systemImage: "envelope", description: Text(folder == .unread ? "Your inbox has no unread messages." : "Messages will appear here."))
                }
            } else {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading \(folder.rawValue.lowercased())…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                List(messages) { message in
                    Button { selectedMessage = message } label: { messageRow(message) }
                        .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .refreshable { await loadFolder(force: true) }
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadFolder(force: true) }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh messages")
                .disabled(isLoading)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Compose Message", systemImage: "square.and.pencil") { showingComposer = true }
            }
        }
        .sheet(isPresented: $showingComposer) {
            SchoologyMessageComposerView {
                if folder == .sent {
                    Task { await loadFolder(force: true) }
                } else {
                    folder = .sent
                }
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
                    SchoologyRichTextText(message.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
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
        let requestedFolder = folder
        loadingFolder = requestedFolder
        defer {
            if loadingFolder == requestedFolder { loadingFolder = nil }
        }
        messages = session.cachedMessages(for: requestedFolder)
        loadError = session.messageErrors[requestedFolder.rawValue]
        let result = await session.loadMessages(folder: requestedFolder, force: force)
        guard !Task.isCancelled, folder == requestedFolder else { return }
        messages = result
        loadError = session.messageErrors[requestedFolder.rawValue]
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
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(thread, id: \.threadIdentity) { item in
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
                                SchoologyRichTextText(item.body.isEmpty ? " " : item.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                if !item.attachments.isEmpty {
                                    SchoologyAttachmentsButton(attachments: item.attachments)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .refreshable {
                    let loaded = await session.loadMessageThread(message, folder: folder)
                    thread = loaded
                    error = loaded.isEmpty ? (session.errorMessage ?? "No conversation content was returned.") : nil
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
    var body: some View {
        List {
            if let error = session.notificationsError, !session.notifications.isEmpty {
                Section {
                    Label("Couldn't refresh notifications: \(error)", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(session.notifications) { notification in
                NavigationLink {
                    SchoologyNotificationDetailView(notification: notification)
                } label: {
                    SchoologyNotificationRow(notification: notification)
                }
                .task(id: notification.id) {
                    if notification.id == session.notifications.last?.id {
                        await session.loadNotifications()
                    }
                }
            }
            if session.isLoadingMoreNotifications {
                HStack { Spacer(); ProgressView("Loading more…"); Spacer() }
                    .listRowSeparator(.hidden)
            }
        }
        .overlay {
            if session.isLoadingNotifications && session.notifications.isEmpty {
                ProgressView("Loading notifications…")
            } else if let error = session.notificationsError, session.notifications.isEmpty {
                ContentUnavailableView("Unable to load notifications", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if session.hasLoadedNotifications && session.notifications.isEmpty {
                ContentUnavailableView("No notifications", systemImage: "bell", description: Text("New Schoology notifications will appear here."))
            }
        }
        .schoologyInsetGroupedListStyle()
        .navigationTitle("Notifications")
        .refreshable { await session.loadNotifications(force: true) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await session.loadNotifications(force: true) }
                } label: {
                    if session.isLoadingNotifications {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh")
                .disabled(session.isLoadingNotifications)
            }
        }
        .task {
            if !session.hasLoadedNotifications { await session.loadNotifications() }
        }
    }
}

