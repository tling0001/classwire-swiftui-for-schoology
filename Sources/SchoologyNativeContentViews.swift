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
                        Text(discussion.body.isEmpty ? "No discussion content." : discussion.body).textSelection(.enabled)
                        if let url = discussion.url { Link(destination: url) { Label("Open attachment", systemImage: "paperclip") } }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Discussion").font(.headline)
                if comments.isEmpty && !loading { ContentUnavailableView("No replies yet", systemImage: "bubble.left") }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.title).font(.subheadline.weight(.semibold))
                        Text(comment.body).textSelection(.enabled)
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
                        Text(event.body.isEmpty ? "No event description." : event.body).textSelection(.enabled)
                        if let url = event.url { Link(destination: url) { Label("Open attachment", systemImage: "paperclip") } }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Comments").font(.headline)
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.title).font(.subheadline.weight(.semibold))
                        Text(comment.body)
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

struct SchoologyAssignmentDetailView: View {
    @Environment(AppSession.self) private var session
    let sectionID: String
    let assignmentID: String
    let title: String
    @State private var assignment: SchoologyProfileItem?
    @State private var comments: [SchoologyProfileItem] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if loading { ProgressView("Loading assignment…").frame(maxWidth: .infinity) }
                else if let error { ContentUnavailableView("Unable to load assignment", systemImage: "exclamationmark.triangle", description: Text(error)) }
                if let assignment {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(assignment.title).font(.title2.weight(.semibold))
                        if !assignment.subtitle.isEmpty { Label(assignment.subtitle, systemImage: "calendar").font(.caption).foregroundStyle(.secondary) }
                        Text(assignment.body.isEmpty ? "No assignment description." : assignment.body).textSelection(.enabled)
                        if let url = assignment.url {
                            NavigationLink { SchoologyEmbeddedWebView(url: url, title: assignment.title) } label: {
                                Label("Open assignment in Schoology", systemImage: "arrow.up.right.square")
                            }
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Comments").font(.headline)
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.title).font(.subheadline.weight(.semibold))
                        Text(comment.body).textSelection(.enabled)
                        if !comment.subtitle.isEmpty { Text(comment.subtitle).font(.caption).foregroundStyle(.secondary) }
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
        .task(id: assignmentID) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; error = nil
        do {
            async let detail = session.loadAssignment(sectionID: sectionID, assignmentID: assignmentID)
            async let replies = session.loadAssignmentComments(sectionID: sectionID, assignmentID: assignmentID)
            assignment = try await detail
            comments = try await replies
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func postComment() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await session.postComment(realm: "sections", realmID: sectionID, entity: "assignments", entityID: assignmentID, body: text)
            draft = ""
            comments = try await session.loadAssignmentComments(sectionID: sectionID, assignmentID: assignmentID)
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

struct SchoologyResourceFolderView: View {
    @Environment(AppSession.self) private var session
    let groupID: String
    let item: SchoologyProfileItem
    @State private var resources: [SchoologyProfileItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if item.kind == "folder" {
                List(resources) { resource in
                    NavigationLink {
                        if resource.kind == "folder" {
                            SchoologyResourceFolderView(groupID: groupID, item: resource)
                        } else if let url = resource.url {
                            SchoologyEmbeddedWebView(url: url, title: resource.title)
                        } else {
                            SchoologyProfileItemDetailSheet(item: resource)
                        }
                    } label: {
                        Label(resource.title, systemImage: resource.kind == "folder" ? "folder" : "doc")
                    }
                }
                .overlay {
                    if loading { ProgressView("Loading resources…") }
                    else if let error { ContentUnavailableView("Unable to load resources", systemImage: "exclamationmark.triangle", description: Text(error)) }
                    else if resources.isEmpty { ContentUnavailableView("Empty folder", systemImage: "folder") }
                }
                .task(id: item.id) {
                    loading = true; error = nil
                    do { resources = try await session.loadGroupResources(groupID: groupID, folderID: item.id, collectionID: item.collectionID) }
                    catch { self.error = error.localizedDescription }
                    loading = false
                }
                .navigationTitle(item.title)
            } else if let url = item.url {
                SchoologyEmbeddedWebView(url: url, title: item.title)
            } else {
                SchoologyProfileItemDetailSheet(item: item)
            }
        }
    }
}

struct SchoologyPersonProfileView: View {
    @Environment(AppSession.self) private var session
    let userID: String
    @State private var person: SchoologyProfileItem?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if loading { ProgressView("Loading profile…") }
            if let error { ContentUnavailableView("Unable to load profile", systemImage: "exclamationmark.triangle", description: Text(error)) }
            if let person {
                Section {
                    Text(person.title).font(.title2.weight(.semibold))
                    if !person.body.isEmpty { Text(person.body).textSelection(.enabled) }
                    if !person.subtitle.isEmpty { Text(person.subtitle).foregroundStyle(.secondary) }
                }
                if let url = person.url { Section { Link("Open profile in Schoology", destination: url) } }
            }
        }
        .navigationTitle("Profile")
        .task(id: userID) {
            loading = true; error = nil
            do { person = try await session.loadPersonProfile(userID: userID) }
            catch { self.error = error.localizedDescription }
            loading = false
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
        .task {
            do { cookies = try await session.loadWebSessionCookies() }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

#if os(iOS)
import UIKit
struct SchoologyCookieWebView: UIViewRepresentable {
    let url: URL
    let cookies: [SchoologyWebCookie]
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        let store = view.configuration.websiteDataStore.httpCookieStore
        Task { @MainActor in
            for item in cookies {
                if let cookie = HTTPCookie(properties: [.domain: item.domain, .path: item.path, .name: item.name, .value: item.value, .secure: "TRUE"]) {
                    await store.setCookie(cookie)
                }
            }
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#elseif os(macOS)
import AppKit
struct SchoologyCookieWebView: NSViewRepresentable {
    let url: URL
    let cookies: [SchoologyWebCookie]
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        let store = view.configuration.websiteDataStore.httpCookieStore
        Task { @MainActor in
            for item in cookies {
                if let cookie = HTTPCookie(properties: [.domain: item.domain, .path: item.path, .name: item.name, .value: item.value, .secure: "TRUE"]) {
                    await store.setCookie(cookie)
                }
            }
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif
