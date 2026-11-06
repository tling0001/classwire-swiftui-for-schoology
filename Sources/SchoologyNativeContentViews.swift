import SwiftUI
import WebKit

struct SchoologyDiscussionDetailView: View {
    @Environment(AppSession.self) private var session
    @ScaledMetric(relativeTo: .body) private var richTextMinimumFontSize: CGFloat = 15.5
    let realm: String
    let realmID: String
    let itemID: String
    let title: String
    @State private var discussion: SchoologyProfileItem?
    @State private var selectedTab: SchoologyAssignmentTab = .info
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && discussion == nil {
                ProgressView("Loading discussion…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, discussion == nil {
                ContentUnavailableView("Unable to load discussion", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let discussion {
                discussionTabs(discussion)
            }
        }
        .navigationTitle(discussion?.title ?? title)
        .task(id: itemID) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func discussionTabs(_ discussion: SchoologyProfileItem) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            modernDiscussionTabs(discussion)
        } else {
            legacyDiscussionTabs(discussion)
        }
        #else
        modernDiscussionTabs(discussion)
        #endif
    }

    @available(macOS 15.0, *)
    private func modernDiscussionTabs(_ discussion: SchoologyProfileItem) -> some View {
        TabView(selection: $selectedTab) {
            Tab("Info", systemImage: "info.circle", value: SchoologyAssignmentTab.info) {
                infoPane(discussion)
            }
            Tab("Discussion", systemImage: "bubble.left", value: SchoologyAssignmentTab.comments) {
                SchoologyEntityCommentsView(
                    title: "Discussion",
                    entityID: itemID,
                    loadComments: { try await session.loadDiscussionComments(realm: realm, realmID: realmID, discussionID: itemID) },
                    submitComment: { body, parentID in
                        try await session.postDiscussionComment(realm: realm, realmID: realmID, discussionID: itemID, body: body, parentID: parentID)
                    }
                )
            }
        }
    }

    private func legacyDiscussionTabs(_ discussion: SchoologyProfileItem) -> some View {
        TabView(selection: $selectedTab) {
            infoPane(discussion)
                .tabItem { Label("Info", systemImage: "info.circle") }
                .tag(SchoologyAssignmentTab.info)
            SchoologyEntityCommentsView(
                title: "Discussion",
                entityID: itemID,
                loadComments: { try await session.loadDiscussionComments(realm: realm, realmID: realmID, discussionID: itemID) },
                submitComment: { body, parentID in
                    try await session.postDiscussionComment(realm: realm, realmID: realmID, discussionID: itemID, body: body, parentID: parentID)
                }
            )
            .tabItem { Label("Discussion", systemImage: "bubble.left") }
            .tag(SchoologyAssignmentTab.comments)
        }
    }

    private func infoPane(_ discussion: SchoologyProfileItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(discussion.title).font(.title2.bold())
                    if !discussion.subtitle.isEmpty {
                        Label(discussion.subtitle, systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                    }
                    SchoologyRichTextText(discussion.body.isEmpty ? "No discussion content." : discussion.body, minimumFontSize: richTextMinimumFontSize)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let url = discussion.url {
                        if !discussion.fileName.isEmpty || !discussion.fileMIME.isEmpty || !url.pathExtension.isEmpty {
                            SchoologyAttachmentsDisclosure(attachments: [
                                SchoologyAttachment(
                                    title: discussion.fileName.isEmpty ? discussion.title : discussion.fileName,
                                    url: url,
                                    viewURL: discussion.fileViewURL
                                )
                            ])
                        } else {
                            Link(destination: url) { Label("Open attachment", systemImage: "paperclip") }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            discussion = try await session.loadDiscussion(realm: realm, realmID: realmID, discussionID: itemID)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct SchoologyEventDetailView: View {
    @Environment(AppSession.self) private var session
    @ScaledMetric(relativeTo: .body) private var richTextMinimumFontSize: CGFloat = 15.5
    let realm: String
    let realmID: String
    let eventID: String
    let title: String

    @State private var context: SchoologyEventContext?
    @State private var selectedTab: SchoologyEventTab = .info
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && context == nil {
                ProgressView("Loading event…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, context == nil {
                ContentUnavailableView("Unable to load event", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let context {
                eventTabs(context)
                    .onChange(of: selectedTab) { _, next in
                        if next == .comments && !context.commentsEnabled { selectedTab = .info }
                    }
            }
        }
        .navigationTitle(context?.event.title ?? title)
        .task(id: eventID) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func eventTabs(_ context: SchoologyEventContext) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            modernEventTabs(context)
        } else {
            legacyEventTabs(context)
        }
        #else
        modernEventTabs(context)
        #endif
    }

    @available(macOS 15.0, *)
    private func modernEventTabs(_ context: SchoologyEventContext) -> some View {
        TabView(selection: $selectedTab) {
            Tab("Info", systemImage: "info.circle", value: SchoologyEventTab.info) { infoPane(context) }
            if context.commentsEnabled {
                Tab("Comments", systemImage: "bubble.left", value: SchoologyEventTab.comments) { commentsPane }
            }
        }
    }

    private func legacyEventTabs(_ context: SchoologyEventContext) -> some View {
        TabView(selection: $selectedTab) {
            infoPane(context).tabItem { Label("Info", systemImage: "info.circle") }.tag(SchoologyEventTab.info)
            if context.commentsEnabled {
                commentsPane.tabItem { Label("Comments", systemImage: "bubble.left") }.tag(SchoologyEventTab.comments)
            }
        }
    }

    private func infoPane(_ context: SchoologyEventContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(context.event.title).font(.title2.bold())
                    if !dateLabel(context).isEmpty {
                        Label(dateLabel(context), systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                    } else if !context.event.subtitle.isEmpty {
                        Label(context.event.subtitle, systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary)
                    }
                    SchoologyRichTextText(context.richDescription.isEmpty ? "No event description." : context.richDescription, minimumFontSize: richTextMinimumFontSize)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                if !context.attachments.isEmpty {
                    SchoologyAttachmentsDisclosure(attachments: context.attachments)
                }
            }.padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private var commentsPane: some View {
        SchoologyEntityCommentsView(
            title: "Comments",
            entityID: eventID,
            loadComments: { try await session.loadEventComments(realm: realm, realmID: realmID, eventID: eventID) },
            submitComment: { body, parentID in
                try await session.postComment(realm: realm, realmID: realmID, entity: "events", entityID: eventID, body: body, parentID: parentID)
            }
        )
    }

    private func dateLabel(_ context: SchoologyEventContext) -> String {
        guard let start = SchoologyValue.date(context.start) else { return context.start }
        let startText = start.formatted(date: context.allDay ? .complete : .abbreviated, time: context.allDay ? .omitted : .shortened)
        guard let end = SchoologyValue.date(context.end), end != start else { return startText }
        let endText = end.formatted(date: context.allDay ? .complete : .abbreviated, time: context.allDay ? .omitted : .shortened)
        return "\(startText) – \(endText)"
    }

    private func load() async {
        if context == nil { isLoading = true }
        errorMessage = nil
        do {
            let loaded = try await session.loadEventContext(realm: realm, realmID: realmID, eventID: eventID)
            context = loaded
            if !loaded.commentsEnabled && selectedTab == .comments { selectedTab = .info }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

struct SchoologyAlbumDetailView: View {
    @Environment(AppSession.self) private var session
    let groupID: String
    let albumID: String
    let title: String
    @State private var media: [SchoologyProfileItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            if loading { ProgressView("Loading album…").padding() }
            else if let error { ContentUnavailableView("Unable to load album", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else if media.isEmpty { ContentUnavailableView("No album photos", systemImage: "photo.on.rectangle") }
            else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(media) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            if let url = item.url {
                                AuthenticatedSchoologyImage(url: url, contentMode: .fit)
                                    .frame(maxWidth: .infinity).frame(height: 180).clipped()
                            } else {
                                Image(systemName: "photo").font(.largeTitle).frame(maxWidth: .infinity).frame(height: 180).background(.quaternary)
                            }
                            Text(item.title).font(.subheadline).lineLimit(2)
                        }.padding(8).background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding()
            }
        }
        .navigationTitle(title)
        .task(id: albumID) {
            loading = true; error = nil
            do { media = try await session.loadGroupAlbum(groupID: groupID, albumID: albumID) }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

private enum SchoologyPersonProfileTab: String, CaseIterable, Identifiable {
    case updates = "Updates"
    case info = "Info"
    case badges = "Badges"
    var id: String { rawValue }
}

struct SchoologyPersonProfileView: View {
    @Environment(AppSession.self) private var session
    let userID: String
    @State private var person: SchoologyProfileItem?
    @State private var updates: [SchoologyActivity] = []
    @State private var badges: [SchoologyProfileItem] = []
    @State private var tab: SchoologyPersonProfileTab = .updates
    @State private var loading = true
    @State private var loadingUpdates = false
    @State private var loadingBadges = false
    @State private var error: String?
    @State private var updatesError: String?
    @State private var badgesError: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Unable to load profile", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let person {
                GeometryReader { proxy in
                    if proxy.size.width >= 900 {
                        wideProfile(person)
                    } else {
                        compactProfile(person)
                    }
                }
            }
        }
        .navigationTitle(person?.title ?? "Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                    .disabled(loading || loadingUpdates || loadingBadges)
            }
        }
        .task(id: userID) { await load() }
        .onChange(of: tab) { _, selected in
            Task { await loadTab(selected) }
        }
    }

    private func compactProfile(_ person: SchoologyProfileItem) -> some View {
        VStack(spacing: 0) {
            profileHeader(person)
                .padding(.horizontal)
                .padding(.top, 12)
            Picker("Profile section", selection: $tab) {
                ForEach(SchoologyPersonProfileTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .schoologyNavigationTabPickerStyle()
            .padding()
            profileTabContent(person)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func wideProfile(_ person: SchoologyProfileItem) -> some View {
        VStack(spacing: 0) {
            profileHeader(person)
                .padding(14)
            HStack(alignment: .top, spacing: 0) {
                profilePane("Updates") { profileTabContent(person, selected: .updates) }
                Divider()
                profilePane("Info") { profileTabContent(person, selected: .info) }
                Divider()
                profilePane("Badges") { profileTabContent(person, selected: .badges) }
            }
        }
    }

    private func profileHeader(_ person: SchoologyProfileItem) -> some View {
        SchoologyProfileInfobox(
            title: person.title,
            subtitle: person.schoolName.isEmpty ? nil : person.schoolName,
            imageURL: person.pictureURL,
            fallbackSymbol: "person.crop.circle.fill",
            details: [person.preferredName, person.role]
        )
    }

    private func profilePane<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.horizontal, 14).padding(.top, 14)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func profileTabContent(_ person: SchoologyProfileItem, selected: SchoologyPersonProfileTab? = nil) -> some View {
        let selectedTab = selected ?? tab
        switch selectedTab {
        case .updates:
            if loadingUpdates && updates.isEmpty {
                ProgressView("Loading updates…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let updatesError, updates.isEmpty {
                ContentUnavailableView("Unable to load updates", systemImage: "exclamationmark.triangle", description: Text(updatesError))
            } else if updates.isEmpty {
                ContentUnavailableView("No updates", systemImage: "text.bubble")
            } else {
                ScrollView {
                    RecentActivityView(activities: updates)
                        .padding(12)
                }
            }
        case .info:
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !person.body.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("About").font(.headline)
                            SchoologyRichTextText(person.body).textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(spacing: 0) {
                        profileInfoRow("Email", value: person.email, symbol: "envelope")
                        profileInfoRow("Username", value: person.username, symbol: "person.text.rectangle")
                        profileInfoRow("First Name", value: person.firstName, symbol: "person")
                        profileInfoRow("Last Name", value: person.lastName, symbol: "person")
                        profileInfoRow("Role", value: person.role, symbol: "person.badge")
                        profileInfoRow("School", value: person.schoolName, symbol: "building.2")
                    }
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    if let url = person.url {
                        Link(destination: url) { Label("Open profile in Schoology", systemImage: "arrow.up.right") }
                            .padding(.horizontal, 4)
                    }
                }
                .padding(14)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        case .badges:
            if loadingBadges && badges.isEmpty {
                ProgressView("Loading badges…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let badgesError, badges.isEmpty {
                ContentUnavailableView("Unable to load badges", systemImage: "exclamationmark.triangle", description: Text(badgesError))
            } else if badges.isEmpty {
                ContentUnavailableView("No badges", systemImage: "rosette")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(badges) { badge in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(badge.title, systemImage: "rosette")
                                    .font(.headline)
                                if !badge.body.isEmpty {
                                    SchoologyRichTextText(badge.body).foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    @ViewBuilder
    private func profileInfoRow(_ title: String, value: String, symbol: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: symbol)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 112, alignment: .leading)
                Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            if title != "School" { Divider() }
        }
    }

    private func load() async {
        loading = true
        error = nil
        updatesError = nil
        badgesError = nil
        do {
            person = try await session.loadPersonProfile(userID: userID)
            loading = false
            loadingUpdates = true
            loadingBadges = true
            async let updatesRequest: [SchoologyActivity]? = try? await session.loadPersonUpdates(userID: userID)
            async let badgesRequest: [SchoologyProfileItem]? = try? await session.loadPersonBadges(userID: userID)
            updates = (await updatesRequest) ?? []
            badges = (await badgesRequest) ?? []
            loadingUpdates = false
            loadingBadges = false
        } catch {
            self.error = error.localizedDescription
            loading = false
            loadingUpdates = false
            loadingBadges = false
        }
    }

    private func loadTab(_ selected: SchoologyPersonProfileTab) async {
        guard person != nil else { return }
        if selected == .updates, updates.isEmpty, !loadingUpdates {
            loadingUpdates = true
            do { updates = try await session.loadPersonUpdates(userID: userID); updatesError = nil }
            catch { updatesError = error.localizedDescription }
            loadingUpdates = false
        } else if selected == .badges, badges.isEmpty, !loadingBadges {
            loadingBadges = true
            do { badges = try await session.loadPersonBadges(userID: userID); badgesError = nil }
            catch { badgesError = error.localizedDescription }
            loadingBadges = false
        }
    }
}

struct SchoologyAccountInfoView: View {
    @Environment(AppSession.self) private var session
    var body: some View {
        let host = session.canadianServer ? "app.schoologyca.com" : "app.schoology.com"
        SchoologyEmbeddedWebView(url: URL(string: "https://\(host)/settings/account")!, title: "Account Info")
    }
}

struct SchoologyEmbeddedWebView: View {
    @Environment(AppSession.self) private var session
    let url: URL
    let title: String
    var requiresWebSession = true
    @State private var cookies: [SchoologyWebCookie] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { ProgressView("Preparing secure Schoology session…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error { ContentUnavailableView("Unable to open Schoology", systemImage: "exclamationmark.triangle", description: Text(error)) }
            else {
                SchoologyCookieWebView(url: url, cookies: cookies)
            }
        }
        .navigationTitle(title)
        .task(id: url) {
            if requiresWebSession {
                do { cookies = try await session.loadWebSessionCookies() }
                catch { self.error = error.localizedDescription }
            }
            loading = false
        }
    }
}

#if os(iOS)
import UIKit
struct SchoologyCookieWebView: UIViewRepresentable {
    let url: URL
    let cookies: [SchoologyWebCookie]
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        let store = view.configuration.websiteDataStore.httpCookieStore
        Task { @MainActor in
            for item in cookies {
                if let cookie = HTTPCookie(properties: [.domain: item.domain, .path: item.path, .name: item.name, .value: item.value, .secure: "TRUE"]) { await store.setCookie(cookie) }
            }
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            webView.load(navigationAction.request)
            return nil
        }
    }
}
#elseif os(macOS)
import AppKit
struct SchoologyCookieWebView: NSViewRepresentable {
    let url: URL
    let cookies: [SchoologyWebCookie]
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        let store = view.configuration.websiteDataStore.httpCookieStore
        Task { @MainActor in
            for item in cookies {
                if let cookie = HTTPCookie(properties: [.domain: item.domain, .path: item.path, .name: item.name, .value: item.value, .secure: "TRUE"]) { await store.setCookie(cookie) }
            }
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            webView.load(navigationAction.request)
            return nil
        }
    }
}
#endif
