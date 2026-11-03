import Foundation
struct SchoologyNotificationPage: Sendable {
    let notifications: [SchoologyNotification]
    let count: Int
    let unviewedCount: Int
    let hasMore: Bool
    static func decode(_ data: Data, start: Int, limit: Int) -> SchoologyNotificationPage {
        let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return SchoologyNotification.decodePage(value, start: start, limit: limit)
    }
}
