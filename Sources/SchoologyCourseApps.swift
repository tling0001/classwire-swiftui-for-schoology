import Foundation
import SwiftUI

struct SchoologyCourseApp: Identifiable, Sendable {
    let id: String
    let title: String
    let logoURL: URL?
    let launchURL: URL?

    static func decodeList(_ data: Data) -> [SchoologyCourseApp] {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        let root = (json["data"] as? [String: Any]) ?? json
        let extra = SchoologyValue.list(root["@extra"] ?? root["extra"], keys: ["items", "data"])
        let items = SchoologyValue.list(root["@items"] ?? root["items"], keys: ["items", "data"])
        let availableIDs = Set(items.compactMap { SchoologyValue.optionalString($0["@id"] ?? $0["id"]) })
        return extra.compactMap { item in
            let idLink = SchoologyValue.optionalString(item["@id"] ?? item["idLink"] ?? item["id_link"])
            guard let idLink, availableIDs.contains(idLink) else { return nil }
            let links = (item["@links"] as? [String: Any]) ?? (item["links"] as? [String: Any]) ?? [:]
            let launch = (links["launch"] as? [String: Any]) ?? [:]
            let launchValue = SchoologyValue.optionalString(launch["@id"] ?? launch["id"] ?? launch["href"] ?? launch["url"])
            let launchURL = launchValue.flatMap { URL(string: $0) }
            let appID = launchURL?.path.split(separator: "/").dropLast().last.map(String.init)
            return SchoologyCourseApp(
                id: appID ?? SchoologyValue.optionalString(item["id"]) ?? idLink,
                title: SchoologyValue.string(item["title"] ?? item["name"], fallback: "Course App"),
                logoURL: SchoologyValue.url(item["logoUrl"] ?? item["logo_url"] ?? item["logo"]),
                launchURL: launchURL
            )
        }
    }
}

struct SchoologyCourseAppLaunchView: View {
    @Environment(AppSession.self) private var session
    let courseID: String
    let app: SchoologyCourseApp
    @State private var launchURL: URL?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if let launchURL {
                SchoologyEmbeddedWebView(url: launchURL, title: app.title, requiresWebSession: false)
            } else if isLoading {
                ProgressView("Opening \(app.title)…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Unable to open course app", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            }
        }
        .navigationTitle(app.title)
        .task(id: app.id) {
            isLoading = true
            error = nil
            do {
                // The official v2 launch URL carries its own short-lived authentication token.
                launchURL = try await session.launchCourseApp(app, courseID: courseID)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
