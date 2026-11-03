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

    func signOut() {
        KeychainStore.clear()
        auth = nil
        user = nil
        courses = []
        groups = []
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
