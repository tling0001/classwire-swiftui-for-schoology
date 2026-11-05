import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
enum SchoologyPushNotifications {
    private(set) static var session: AppSession?
    private(set) static var activeDeviceToken: String?

    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "schoology.notifications.enabled")
    }

    static var foregroundPresentationOptions: UNNotificationPresentationOptions {
        UserDefaults.standard.bool(forKey: "schoology.notifications.sound")
            ? [.banner, .list, .sound]
            : [.banner, .list]
    }

    static func configure(_ session: AppSession) { self.session = session }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func setEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "schoology.notifications.enabled")
        if enabled {
            UserDefaults.standard.set(true, forKey: "schoology.notifications.everEnabled")
            await registerIfAuthorized()
            return
        }
        if let activeDeviceToken, let session {
            try? await unregister(activeDeviceToken, using: session)
            self.activeDeviceToken = nil
        } else if UserDefaults.standard.bool(forKey: "schoology.notifications.everEnabled") {
            registerWithAPNs()
        }
    }

    static func registerIfAuthorized() async {
        #if os(macOS)
        // The Developer ID distribution is not provisioned for APNs.
        return
        #else
        let wasEnabled = UserDefaults.standard.bool(forKey: "schoology.notifications.everEnabled")
        guard notificationsEnabled || wasEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral
        guard (notificationsEnabled && isAuthorized) || (!notificationsEnabled && wasEnabled) else { return }
        registerWithAPNs()
        #endif
    }

    private static func registerWithAPNs() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    static func didRegister(deviceToken: Data, platform: String) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard notificationsEnabled else {
            if let session { try? await unregister(token, using: session) }
            activeDeviceToken = nil
            return
        }
        activeDeviceToken = token
        guard let session, let auth = session.auth else { return }

        #if os(iOS)
        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let path = "alert/device/\(token)"
        let body: [String: String] = [
            "device_os": platform,
            "device_name": deviceName,
            "device_os_version": osVersion,
            "app_version": "2026.10.0"
        ]
        do {
            let data = try await SchoologyAPI.shared.get(path, auth: auth)
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let payload = (root["data"] as? [String: Any]) ?? (root["response"] as? [String: Any]) ?? root
            if Int(SchoologyValue.string(payload["status"])) == 1 { return }
            _ = try await SchoologyAPI.shared.putJSON(path, auth: auth, body: body)
        } catch {
            _ = try? await SchoologyAPI.shared.postJSON(path, auth: auth, body: body)
        }
    }

    private static func unregister(_ token: String, using session: AppSession) async throws {
        guard let auth = session.auth else { return }
        _ = try await SchoologyAPI.shared.delete("alert/device/\(token)", auth: auth)
    }

    static func refreshNotifications() async {
        await session?.loadNotifications(force: true, markRead: false)
    }

    static func handleNotificationTap() { session?.destination = .notifications }
}

#if os(iOS)
@MainActor
final class SchoologyNotificationAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await SchoologyPushNotifications.didRegister(deviceToken: deviceToken, platform: "iOS") }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            await SchoologyPushNotifications.refreshNotifications()
            completionHandler(.newData)
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(SchoologyPushNotifications.foregroundPresentationOptions)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in SchoologyPushNotifications.handleNotificationTap(); completionHandler() }
    }
}
#elseif os(macOS)
@MainActor
final class SchoologyNotificationAppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { UNUserNotificationCenter.current().delegate = self }
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await SchoologyPushNotifications.didRegister(deviceToken: deviceToken, platform: "macOS") }
    }
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { }
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in await SchoologyPushNotifications.refreshNotifications() }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(SchoologyPushNotifications.foregroundPresentationOptions)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in SchoologyPushNotifications.handleNotificationTap(); completionHandler() }
    }
}
#endif
