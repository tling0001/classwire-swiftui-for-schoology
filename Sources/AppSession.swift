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

    private let api = SchoologyAPI.shared

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
            api.useCanadianServer = canadian
            let credentials = try await api.login(username: username, password: password, schoolID: schoolID)
            let profile = try await api.currentUser(auth: credentials)
            KeychainStore.save(credentials)
            auth = credentials
            user = profile
            destination = .home
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let auth else { return }
        do {
            async let courseResponse = api.get("sections", auth: auth, params: ["limit": "50", "enrollment_status": "1"])
            async let groupResponse = api.get("groups", auth: auth, params: ["limit": "50"])
            async let activityResponse = api.get("users/\(auth.userID)/recent_activity", auth: auth, params: ["limit": "30"])
            let (courseJSON, groupJSON, activityJSON) = try await (courseResponse, groupResponse, activityResponse)
            courses = SchoologyCourse.decodeList(courseJSON["section"] ?? courseJSON["sections"])
            groups = SchoologyGroup.decodeList(groupJSON["group"] ?? groupJSON["groups"])
            activities = SchoologyActivity.decodeList(activityJSON["recent_activity"] ?? activityJSON["activity"])
        } catch {
            errorMessage = error.localizedDescription
        }
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
