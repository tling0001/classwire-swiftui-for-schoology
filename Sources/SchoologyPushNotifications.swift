import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let schoologyPushRegistrationDidChange = Notification.Name("schoologyPushRegistrationDidChange")
}

@MainActor
enum SchoologyPushNotifications {
    private(set) static var session: AppSession?
    private(set) static var activeDeviceToken: String? = UserDefaults.standard.string(forKey: "schoology.notifications.deviceToken")
    private(set) static var registrationError: String?

    private static let tokenDefaultsKey = "schoology.notifications.deviceToken"
    private static let registeredUserDefaultsKey = "schoology.notifications.registeredUserID"

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
        activeDeviceToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func setEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "schoology.notifications.enabled")
        if enabled {
            UserDefaults.standard.set(true, forKey: "schoology.notifications.everEnabled")
            await registerIfAuthorized()
        } else {
            let hasStoredToken = activeDeviceToken != nil || UserDefaults.standard.string(forKey: tokenDefaultsKey) != nil
            await unregisterStoredToken()
            if !hasStoredToken { setRegistrationError(nil) }
        }
    }

    static func registerIfAuthorized() async {
        #if os(macOS)
        // The current Developer ID target has no APNs provisioning profile.
        return
        #else
        guard notificationsEnabled else {
            await unregisterStoredToken()
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
        registerWithAPNs()
        await registerCachedTokenIfNeeded()
        #endif
    }

    private static func registerWithAPNs() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    static func didRegister(deviceToken: Data, platform: String) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else {
            setRegistrationError("Apple returned an empty push notification device token.")
            return
        }
        let previousToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
        if previousToken != token {
            UserDefaults.standard.removeObject(forKey: registeredUserDefaultsKey)
        }
        activeDeviceToken = token
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        if !notificationsEnabled {
            await unregisterStoredToken()
            return
        }
        if let userID = session?.auth?.userID,
           UserDefaults.standard.string(forKey: registeredUserDefaultsKey) == userID {
            return
        }
        await registerDeviceToken(token, platform: platform)
    }

    static func didFailToRegister(_ error: Error) {
        setRegistrationError(error.localizedDescription)
    }

    private static func registerCachedTokenIfNeeded() async {
        guard notificationsEnabled,
              let token = activeDeviceToken ?? UserDefaults.standard.string(forKey: tokenDefaultsKey),
              let auth = session?.auth else { return }
        guard UserDefaults.standard.string(forKey: registeredUserDefaultsKey) != auth.userID else { return }
        #if os(iOS)
        let platform = "iOS"
        #else
        let platform = "macOS"
        #endif
        await registerDeviceToken(token, platform: platform)
    }

    private static func registerDeviceToken(_ token: String, platform: String) async {
        guard let auth = session?.auth else {
            // Keep the APNs token; sign-in/restore will retry once credentials are available.
            setRegistrationError(nil)
            return
        }

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
        do {
            // Match Schoology's Android registrar: POST checks the current token
            // status; PUT updates the registration when the status isn't active.
            let data = try await SchoologyAPI.shared.postJSON(path, auth: auth, body: body)
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let payload = (root["data"] as? [String: Any]) ?? (root["response"] as? [String: Any]) ?? root
            if Int(SchoologyValue.string(payload["status"])) != 1 {
                _ = try await SchoologyAPI.shared.putJSON(path, auth: auth, body: body)
            }
            UserDefaults.standard.set(auth.userID, forKey: registeredUserDefaultsKey)
            setRegistrationError(nil)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
    }

    private static func unregisterStoredToken() async {
        guard let token = activeDeviceToken ?? UserDefaults.standard.string(forKey: tokenDefaultsKey),
              let auth = session?.auth else { return }
        do {
            _ = try await SchoologyAPI.shared.delete("alert/device/\(token)", auth: auth)
            UserDefaults.standard.removeObject(forKey: registeredUserDefaultsKey)
            setRegistrationError(nil)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
    }

    static func unregisterForSignOut(auth: SchoologyAuth?) async {
        guard let token = activeDeviceToken ?? UserDefaults.standard.string(forKey: tokenDefaultsKey),
              let auth else { return }
        do {
            _ = try await SchoologyAPI.shared.delete("alert/device/\(token)", auth: auth)
        } catch {
            setRegistrationError(error.localizedDescription)
        }
        UserDefaults.standard.removeObject(forKey: registeredUserDefaultsKey)
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
