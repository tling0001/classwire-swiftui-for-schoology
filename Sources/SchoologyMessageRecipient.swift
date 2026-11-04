import Foundation
struct SchoologyMessageRecipient: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    static func decodeList(_ data: Data) -> [SchoologyMessageRecipient] {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let root = (json["data"] as? [String: Any]) ?? (json["response"] as? [String: Any]) ?? json
        return SchoologyValue.list(root, keys: ["recipient", "recipients", "user", "users", "items"]).compactMap { row in
            let nested = (row["user"] as? [String: Any]) ?? (row["recipient"] as? [String: Any]) ?? row
            guard let id = SchoologyValue.optionalString(nested["id"] ?? nested["uid"] ?? nested["user_id"] ?? nested["userId"] ?? nested["recipient_id"] ?? nested["recipientId"]) else { return nil }
            let name = SchoologyValue.string(nested["name_display"] ?? nested["nameDisplay"] ?? nested["display_name"] ?? nested["displayName"] ?? nested["name"] ?? nested["full_name"] ?? nested["fullName"], fallback: "Schoology user")
            return SchoologyMessageRecipient(id: id, name: name)
        }
    }
}
