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
    private(set) static var registrationError: String?
    private static var registeredUserID: String?

    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "schoology.notifications.enabled")
    }

    static var foregroundPresentationOptions: UNNotificationPresentationOptions {
        UserDefaults.standard.bool(forKey: "schoology.notifications.sound")
            ? [.banner, .list, .sound]
            : [.banner, .list]
    }

    static func configure(_ session: AppSession) {
        self.session = session
        // Older builds persisted APNs tokens. Apple requires requesting a fresh
        // token at launch, so remove those legacy values during migration.
        UserDefaults.standard.removeObject(forKey: "schoology.notifications.deviceToken")
        UserDefaults.standard.removeObject(forKey: "schoology.notifications.registeredUserID")
        registeredUserID = nil
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func setEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "schoology.notifications.enabled")
        if enabled {
            await registerIfAuthorized()
        } else {
            await unregisterActiveToken()
            registeredUserID = nil
        }
    }

    static func registerIfAuthorized() async {
        guard notificationsEnabled else {
            await unregisterActiveToken()
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral
        guard isAuthorized else {
            setRegistrationError("Allow notifications for Schoology in system settings before registering this device.")
            return
        }
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
        await registerCurrentTokenIfNeeded()
    }

    static func didRegister(deviceToken: Data, platform: String) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else {
            setRegistrationError("Apple returned an empty push notification device token.")
            return
        }
        activeDeviceToken = token
        registeredUserID = nil
        guard notificationsEnabled else { return }
        await registerDeviceToken(token, platform: platform)
    }

    static func didFailToRegister(_ error: Error) {
        setRegistrationError(error.localizedDescription)
    }

    private static func registerCurrentTokenIfNeeded() async {
        guard notificationsEnabled, let token = activeDeviceToken else { return }
        #if os(iOS)
        let platform = "iOS"
        #else
        let platform = "macOS"
        #endif
        await registerDeviceToken(token, platform: platform)
    }

    private static func registerDeviceToken(_ token: String, platform: String) async {
        guard let auth = session?.auth else {
            // Keep the token in memory only; sign-in/restore retries registration.
            setRegistrationError(nil)
            return
        }
        guard registeredUserID != auth.userID else { return }

        #if os(iOS)
        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let path = "alert/device/\(token)"
        let body: [String: Any] = [
            "device_os": platform,
            "device_name": deviceName,
            "device_os_version": osVersion,
            "app_version": "2026.10.0"
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else {
            setRegistrationError("Could not encode the push registration request.")
            return
        }
        do {
            // Match the Android registrar's status check and update/create fallback.
            do {
                let statusData = try await SchoologyAPI.shared.get(path, auth: auth)
                let root = (try? JSONSerialization.jsonObject(with: statusData)) as? [String: Any] ?? [:]
                let payload = (root["data"] as? [String: Any]) ?? (root["response"] as? [String: Any]) ?? root
                if Int(SchoologyValue.string(payload["status"])) != 1 {
                    _ = try await SchoologyAPI.shared.putJSONData(path, auth: auth, bodyData: bodyData)
                }
            } catch {
                _ = try await SchoologyAPI.shared.postJSONData(path, auth: auth, bodyData: bodyData)
            }
            registeredUserID = auth.userID
            setRegistrationError(nil)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
    }

    private static func unregisterActiveToken() async {
        guard let token = activeDeviceToken, let auth = session?.auth else { return }
        do {
            _ = try await SchoologyAPI.shared.delete("alert/device/\(token)", auth: auth)
            registeredUserID = nil
            setRegistrationError(nil)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
    }

    static func unregisterForSignOut(auth: SchoologyAuth?) async {
        guard let token = activeDeviceToken, let auth else { return }
        do {
            _ = try await SchoologyAPI.shared.delete("alert/device/\(token)", auth: auth)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
        registeredUserID = nil
    }

    private static func setRegistrationError(_ message: String?) {
        registrationError = message
        NotificationCenter.default.post(name: .schoologyPushRegistrationDidChange, object: nil)
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
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SchoologyPushNotifications.didFailToRegister(error)
    }
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
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        SchoologyPushNotifications.didFailToRegister(error)
    }
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
