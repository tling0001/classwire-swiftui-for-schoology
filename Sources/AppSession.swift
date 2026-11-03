import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppSession {
    var auth: SchoologyAuth?
    var user: SchoologyUser?
    var destination: AppDestination = .home
    var isLoading = false
    var errorMessage: String?
    var courses: [SchoologyCourse] = []
    var groups: [SchoologyGroup] = []
    var activities: [SchoologyActivity] = []
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
        // Verify the access token once before persisting it, then bind the returned
        // Schoology user ID to the credentials used by the rest of the app.
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
        await refresh()
    }

    func refresh() async {
        guard let auth else { return }
        do {
            async let activityData = api.get("recent", auth: auth, params: ["start": "0", "limit": "20", "with_attachments": "TRUE", "richtext": "1"])
            async let courseData = api.get("users/\(auth.userID)/sections", auth: auth, params: ["limit": "100"])
            async let groupData = api.get("users/\(auth.userID)/groups", auth: auth, params: ["limit": "100"])
            let (activity, course, group) = try await (activityData, courseData, groupData)
            let activityJSON = Self.object(activity)
            let courseJSON = Self.object(course)
            let groupJSON = Self.object(group)
            activities = SchoologyActivity.decodeList(activityJSON["update"] ?? activityJSON["updates"])
            courses = SchoologyCourse.decodeList(courseJSON["section"] ?? courseJSON["sections"])
            groups = SchoologyGroup.decodeList(groupJSON["group"] ?? groupJSON["groups"])
        } catch {
            errorMessage = error.localizedDescription
        }
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
        destination = .home
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
