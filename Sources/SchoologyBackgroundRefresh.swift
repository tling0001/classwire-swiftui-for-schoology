#if os(iOS)
import BackgroundTasks
import Foundation

enum SchoologyBackgroundRefresh {
    static let identifier = "com.schoologytauri.app.notifications-refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // iOS may defer or reject refresh requests based on system policy and budget.
        }
    }
}
#endif
