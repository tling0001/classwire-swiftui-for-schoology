import SwiftUI
import WebKit

struct SchoologyDiscussionDetailView: View {
    @Environment(AppSession.self) private var session
    let realm: String
    let realmID: String
    let itemID: String
    let title: String
    @State private var discussion: SchoologyProfileItem?
    @State private var comments: [SchoologyProfileItem] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if loading { ProgressView("Loading discussion…").frame(maxWidth: .infinity) }
                if let error { ContentUnavailableView("Unable to load discussion", systemImage: "exclamationmark.triangle", description: Text(error)) }
                if let discussion {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(discussion.title).font(.title2.weight(.semibold))
                        if !discussion.subtitle.isEmpty { Text(discussion.subtitle).font(.caption).foregroundStyle(.secondary) }
                        SchoologyRichTextText(discussion.body.isEmpty ? "No discussion content." : discussion.body).textSelection(.enabled)
                        if let url = discussion.url { Link(destination: url) { Label("Open attachment", systemImage: "paperclip") } }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Discussion").font(.headline)
                if comments.isEmpty && !loading { ContentUnavailableView("No replies yet", systemImage: "bubble.left") }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.title).font(.subheadline.weight(.semibold))
                        SchoologyRichTextText(comment.body).textSelection(.enabled)
                        if !comment.subtitle.isEmpty { Text(comment.subtitle).font(.caption).foregroundStyle(.secondary) }
                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack(alignment: .bottom) {
                    TextField("Add a reply…", text: $draft, axis: .vertical).lineLimit(2...5)
                    Button("Post", systemImage: "paperplane.fill") { Task { await postReply() } }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }.padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .task(id: itemID) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; error = nil
        do {
            async let detail = session.loadDiscussion(realm: realm, realmID: realmID, discussionID: itemID)
            async let replies = session.loadDiscussionComments(realm: realm, realmID: realmID, discussionID: itemID)
            discussion = try await detail
            comments = try await replies
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func postReply() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await session.postComment(realm: realm, realmID: realmID, entity: "discussions", entityID: itemID, body: text)
            draft = ""
            comments = try await session.loadDiscussionComments(realm: realm, realmID: realmID, discussionID: itemID)
        } catch { self.error = error.localizedDescription }
    }
}

struct SchoologyEventDetailView: View {
    @Environment(AppSession.self) private var session
    let realm: String
    let realmID: String
    let eventID: String
    let title: String
    @State private var event: SchoologyProfileItem?
    @State private var comments: [SchoologyProfileItem] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if loading { ProgressView("Loading event…").frame(maxWidth: .infinity) }
                if let error { ContentUnavailableView("Unable to load event", systemImage: "exclamationmark.triangle", description: Text(error)) }
                if let event {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(event.title).font(.title2.weight(.semibold))
                        if !event.subtitle.isEmpty { Label(event.subtitle, systemImage: "calendar").font(.subheadline).foregroundStyle(.secondary) }
                        SchoologyRichTextText(event.body.isEmpty ? "No event description." : event.body).textSelection(.enabled)
                        if let url = event.url { Link(destination: url) { Label("Open attachment", systemImage: "paperclip") } }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Comments").font(.headline)
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.title).font(.subheadline.weight(.semibold))
                        SchoologyRichTextText(comment.body)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                }
                HStack(alignment: .bottom) {
                    TextField("Add a comment…", text: $draft, axis: .vertical).lineLimit(2...5)
                    Button("Post", systemImage: "paperplane.fill") { Task { await postComment() } }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }.padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .task(id: eventID) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; error = nil
        do {
            async let detail = session.loadEvent(realm: realm, realmID: realmID, eventID: eventID)
            async let replies = session.loadEventComments(realm: realm, realmID: realmID, eventID: eventID)
            event = try await detail
            comments = try await replies
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func postComment() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await session.postComment(realm: realm, realmID: realmID, entity: "events", entityID: eventID, body: text)
            draft = ""
            comments = try await session.loadEventComments(realm: realm, realmID: realmID, eventID: eventID)
        } catch { self.error = error.localizedDescription }
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
