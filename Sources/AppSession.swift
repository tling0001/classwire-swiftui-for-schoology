import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppSession {
    var auth: SchoologyAuth?
    var user: SchoologyUser?
    var destination: AppDestination = .home
    var homeSection: HomeSection = .recent
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var courses: [SchoologyCourse] = []
    var groups: [SchoologyGroup] = []
    var notifications: [SchoologyNotification] = []
    var messageFolder = SchoologyMessageFolder.inbox
    var activities: [SchoologyActivity] = []
    var upcomingEvents: [SchoologyUpcomingEvent] = []
    var schoolNames: [String: String] = [:]
    var appearance: AppAppearance = .system
    var canadianServer = UserDefaults.standard.bool(forKey: "schoology.canadian")

    private let api = SchoologyAPI.shared
    private let schoolBrowserAuthenticator = SchoolBrowserAuthenticator()

    init() {
        auth = KeychainStore.loadAuth()
        if let auth {
            Task { await restore(auth) }
        }
    }

    var isSignedIn: Bool { auth != nil }

    func restore(_ credentials: SchoologyAuth) async {
        isLoading = true
        defer { isLoading = false }
        do {
            await api.setCanadianServer(canadianServer)
            let profile = try await api.currentUser(auth: credentials)
            auth = credentials
            user = profile
            await refresh()
        } catch {
            KeychainStore.clear()
            auth = nil
            errorMessage = error.localizedDescription
        }
    }

    func signIn(username: String, password: String, schoolID: String?, canadian: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            canadianServer = canadian
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
            await api.setCanadianServer(canadian)
            let credentials = try await api.login(username: username, password: password, schoolID: schoolID)
            try await establishSession(credentials)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithQRCode(_ qrCode: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            await api.setCanadianServer(canadianServer)
            let credentials = try await api.loginWithQRCode(qrCode)
            try await establishSession(credentials)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelSchoolSignIn() {
        schoolBrowserAuthenticator.cancel()
    }

    func signInThroughSchool(domain: String, canadian: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            canadianServer = canadian
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
            await api.setCanadianServer(canadian)
            let pending = try await api.prepareSchoolBrowserLogin(domain: domain)
            let callback = try await schoolBrowserAuthenticator.authenticate(using: pending.authorizationURL)
            let credentials = try await api.completeSchoolBrowserLogin(pending, callbackURL: callback)
            try await establishSession(credentials)
        } catch is CancellationError {
            // Returning to the school picker cancels authentication intentionally.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func establishSession(_ credentials: SchoologyAuth) async throws {
        let profile = try await api.currentUser(auth: credentials)
        let verifiedCredentials = SchoologyAuth(
            token: credentials.token,
            secret: credentials.secret,
            userID: profile.id
        )
        KeychainStore.save(verifiedCredentials)
        auth = verifiedCredentials
        user = profile
        destination = .home
        homeSection = .recent
        await refresh()
    }

    func refresh() async {
        guard let auth else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let activityRequest = try? api.get("recent", auth: auth, params: [
            "start": "0", "limit": "20", "with_attachments": "TRUE", "richtext": "1"
        ])
        async let courseRequest = try? api.get("users/\(auth.userID)/sections", auth: auth, params: ["limit": "100"])
        async let groupRequest = try? api.get("users/\(auth.userID)/groups", auth: auth, params: ["limit": "100"])
        async let upcomingRequest = try? api.get("users/\(auth.userID)/events", auth: auth, params: [
            "start_date": Self.apiDate(Date()), "start": "0", "limit": "50"
        ])

        let (activityData, courseData, groupData, upcomingData) = await (
            activityRequest, courseRequest, groupRequest, upcomingRequest
        )

        if let activityData {
            activities = SchoologyActivity.decodeList(Self.object(activityData))
            await hydrateActivityAuthors(auth: auth)
        }
        if let courseData {
            courses = SchoologyCourse.decodeList(Self.object(courseData))
        }
        if let groupData {
            groups = SchoologyGroup.decodeList(Self.object(groupData))
        }
        if let upcomingData {
            upcomingEvents = SchoologyUpcomingEvent.decodeList(Self.object(upcomingData))
                .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        }
    }

    func loadSchoolName(for course: SchoologyCourse) async -> String {
        if let cached = schoolNames[course.id] { return cached }
        guard let auth else { return "" }

        var schoolID = course.schoolID
        if let sectionData = try? await api.get("sections/\(course.id)", auth: auth) {
            let sectionJSON = Self.object(sectionData)
            let section = (sectionJSON["section"] as? [String: Any]) ?? sectionJSON
            schoolID = SchoologyValue.optionalString(section["school_id"] ?? section["schoolId"]) ?? schoolID
        }

        guard let schoolID, !schoolID.isEmpty,
              let schoolData = try? await api.get("schools/\(schoolID)", auth: auth) else {
            schoolNames[course.id] = ""
            return ""
        }
        let schoolJSON = Self.object(schoolData)
        let school = (schoolJSON["school"] as? [String: Any]) ?? schoolJSON
        let name = SchoologyValue.string(school["title"] ?? school["name"])
        schoolNames[course.id] = name
        return name
    }

    func loadUpcomingEvents(for course: SchoologyCourse) async -> [SchoologyUpcomingEvent] {
        guard let auth,
              let data = try? await api.get("sections/\(course.id)/events", auth: auth, params: [
                "start_date": Self.apiDate(Date()), "start": "0", "limit": "50"
              ]) else { return [] }
        return SchoologyUpcomingEvent.decodeList(Self.object(data))
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    private func hydrateActivityAuthors(auth: SchoologyAuth) async {
        for index in activities.indices.prefix(20) {
            guard activities[index].authorName.isEmpty,
                  let authorID = activities[index].authorID,
                  let data = try? await api.get("users/\(authorID)", auth: auth) else { continue }
            let json = Self.object(data)
            let user = (json["user"] as? [String: Any]) ?? json
            activities[index].authorName = SchoologyValue.string(
                user["name_display"] ?? user["display_name"] ?? user["name"],
                fallback: "Schoology"
            )
            activities[index].avatarURL = SchoologyValue.url(
                user["picture_url"] ?? user["pictureUrl"] ?? user["picture"] ?? user["photo_url"]
            )
        }
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func object(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }


    func loadMessages(folder: SchoologyMessageFolder, force: Bool = false) async -> [SchoologyMessage] {
        guard let auth else { return [] }
        messageFolder = folder
        let endpoint = folder == .sent ? "messages/sent" : "messages/inbox"
        do {
            let data = try await api.get(endpoint, auth: auth, params: ["limit": "50"])
            let rows = SchoologyMessage.decodeList(Self.object(data))
            var hydrated = rows
            let ids = Set(rows.compactMap { folder == .sent ? $0.recipientID : $0.authorID })
            var users: [String: SchoologyUser] = [:]
            for id in ids {
                guard let userData = try? await api.get("users/\(id)", auth: auth) else { continue }
                let userJSON = Self.object(userData)
                let raw = (userJSON["user"] as? [String: Any]) ?? userJSON
                guard raw["id"] != nil else { continue }
                users[id] = SchoologyUser(
                    id: id,
                    nameDisplay: SchoologyValue.string(raw["name_display"] ?? raw["display_name"] ?? raw["name"], fallback: "Schoology user"),
                    pictureURL: SchoologyValue.url(raw["picture_url"] ?? raw["pictureUrl"] ?? raw["picture"])
                )
            }
            for index in hydrated.indices {
                let id = folder == .sent ? hydrated[index].recipientID : hydrated[index].authorID
                hydrated[index].personName = users[id ?? ""]?.nameDisplay ?? (id == auth.userID ? "You" : "Schoology")
                hydrated[index].personPictureURL = users[id ?? ""]?.pictureURL
            }
            return folder == .unread ? hydrated.filter(\.isUnread) : hydrated
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func loadMessageThread(_ message: SchoologyMessage, folder: SchoologyMessageFolder) async -> [SchoologyMessage] {
        guard let auth else { return [] }
        let sourceFolder = folder == .sent ? "sent" : "inbox"
        do {
            let data = try await api.get("messages/\(sourceFolder)/\(message.id)", auth: auth, params: ["with_attachments": "TRUE"])
            let json = Self.object(data)
            let payload = (json["data"] as? [String: Any]) ?? (json["response"] as? [String: Any]) ?? json
            let rows = SchoologyMessage.decodeList(payload)
            var result = rows
            for index in result.indices {
                if result[index].personName.isEmpty, let id = result[index].authorID,
                   let userData = try? await api.get("users/\(id)", auth: auth) {
                    let userJSON = Self.object(userData)
                    let raw = (userJSON["user"] as? [String: Any]) ?? userJSON
                    result[index].personName = SchoologyValue.string(raw["name_display"] ?? raw["display_name"] ?? raw["name"], fallback: "Schoology")
                    result[index].personPictureURL = SchoologyValue.url(raw["picture_url"] ?? raw["pictureUrl"] ?? raw["picture"])
                }
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func loadNotifications() async -> [SchoologyNotification] {
        guard let auth else { return [] }
        do {
            let data = try await api.get("notifications", auth: auth, params: ["limit": "50"])
            let json = Self.object(data)
            notifications = SchoologyNotification.decodeList(json)
            let wrapper = (json["notifications"] as? [String: Any]) ?? json
            let unviewed = SchoologyValue.integer(wrapper["unviewed_count"] ?? wrapper["unviewedCount"] ?? json["unviewed_count"] ?? json["unviewedCount"])
            if unviewed > 0 {
                _ = try? await api.post("notifications/read", auth: auth)
            }
            return notifications
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }


    func loadGroupProfile(_ group: SchoologyGroup) async throws -> SchoologyGroupProfile {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        async let detail = api.get("groups/\(group.id)", auth: auth)
        async let members = api.get("groups/\(group.id)/enrollments", auth: auth, params: ["start":"0","limit":"200","enrollment_status":"1"])
        async let updates = api.get("groups/\(group.id)/updates", auth: auth, params: ["start":"0","limit":"20","with_attachments":"TRUE","richtext":"1"])
        async let events = api.get("groups/\(group.id)/events", auth: auth, params: ["start":Self.apiDate(Date()),"limit":"20"])
        async let discussions = api.get("groups/\(group.id)/discussions", auth: auth, params: ["limit":"50"])
        async let albums = api.get("groups/\(group.id)/albums", auth: auth, params: ["limit":"50"])
        async let resources = api.get("groups/\(group.id)/resources", auth: auth, params: ["limit":"50","with_attachments":"TRUE"])
        let (d,m,u,e,ds,a,r) = try await (detail,members,updates,events,discussions,albums,resources)
        let raw = Self.object(d); let groupJSON = (raw["group"] as? [String:Any]) ?? raw
        let requestPaths = ["updates","discussions","events","albums","resources"].map { "/v1/groups/\(group.id)/\($0)" }
        let permissionData = try? await api.postMultiOptions(requestPaths, auth: auth)
        let permissionJSON = permissionData.map(Self.object) ?? [:]
        return SchoologyGroupProfile(
            group: SchoologyGroup(id:SchoologyValue.string(groupJSON["id"] ?? groupJSON["group_id"],fallback:group.id),
                title:SchoologyValue.string(groupJSON["title"] ?? groupJSON["name"],fallback:group.title),
                schoolID:SchoologyValue.optionalString(groupJSON["school_id"] ?? groupJSON["schoolId"]),
                pictureURL:SchoologyValue.url(groupJSON["picture_url"] ?? groupJSON["pictureUrl"])),
            permissions:SchoologyGroupPermissions.decode(permissionJSON,groupID:group.id),
            members:SchoologyProfileItem.decodeList(Self.object(m),keys:["enrollment","enrollments","member","members","user","users"]),
            updates:SchoologyProfileItem.decodeList(Self.object(u),keys:["update","updates","update_list"]),
            upcoming:SchoologyUpcomingEvent.decodeList(Self.object(e)),
            discussions:SchoologyProfileItem.decodeList(Self.object(ds),keys:["discussion","discussions"]),
            albums:SchoologyProfileItem.decodeList(Self.object(a),keys:["album","albums"]),
            resources:SchoologyProfileItem.decodeList(Self.object(r),keys:["resource","resources","collection","items"]))
    }

    func loadSchoolProfile(_ id: String) async throws -> SchoologySchoolProfile {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        async let detail = api.get("schools/\(id)",auth:auth)
        async let updates = api.get("schools/\(id)/updates",auth:auth,params:["start":"0","limit":"50","with_attachments":"TRUE","richtext":"1"])
        async let events = api.get("schools/\(id)/events",auth:auth,params:["start":Self.apiDate(Date()),"limit":"50"])
        async let resources = api.get("schools/\(id)/resources",auth:auth,params:["start":"0","limit":"200","with_attachments":"TRUE"])
        let (d,u,e,r) = try await (detail,updates,events,resources)
        let raw=Self.object(d); let school=(raw["school"] as? [String:Any]) ?? raw
        return SchoologySchoolProfile(
            school:SchoologyProfileSchool(id:id,title:SchoologyValue.string(school["title"] ?? school["name"],fallback:"School"),
                pictureURL:SchoologyValue.url(school["picture_url"] ?? school["pictureUrl"] ?? school["picture"] ?? school["image"]),
                address:["address1","address2","city","state","postal_code","country"].compactMap{school[$0] as? String}.filter{!$0.isEmpty}.joined(separator:", "),
                phone:SchoologyValue.string(school["phone"])),
            updates:SchoologyProfileItem.decodeList(Self.object(u),keys:["update","updates","update_list","results"]),
            upcoming:SchoologyUpcomingEvent.decodeList(Self.object(e)),
            resources:SchoologyProfileItem.decodeList(Self.object(r),keys:["resource","resources","resource_list"]))
    }

    func loadSchoolDiscussions(_ id: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data=try await api.get("schools/\(id)/discussions",auth:auth,params:["start":"0","limit":"50","with_attachments":"TRUE","richtext":"1"])
        return SchoologyProfileItem.decodeList(Self.object(data),keys:["discussion","discussions"])
    }

    func signOut() {
        KeychainStore.clear()
        auth = nil
        user = nil
        courses = []
        groups = []
        notifications = []
        activities = []
        upcomingEvents = []
        schoolNames = [:]
        destination = .home
        homeSection = .recent
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
