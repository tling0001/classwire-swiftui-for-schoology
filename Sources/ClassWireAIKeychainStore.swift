import Foundation
import Security

enum ClassWireAIKeychainStore {
    private static let service = "com.schoologytauri.app.ai"

    static func save(_ key: String, provider: ClassWireAIProvider) throws {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 8, value.count <= 8192 else {
            throw ClassWireAIError.invalidResponse("The API key is empty or too long.")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            attributes.forEach { insertion[$0.key] = $0.value }
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ClassWireAIError.invalidResponse("Could not save the API key in Keychain (error \(addStatus)).")
            }
        } else if status != errSecSuccess {
            throw ClassWireAIError.invalidResponse("Could not update the API key in Keychain (error \(status)).")
        }
    }

    static func load(provider: ClassWireAIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(provider: ClassWireAIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static let googleRefreshTokenAccount = "google-refresh-token"

    static func saveGoogleRefreshToken(_ token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 16_384 else {
            throw ClassWireAIError.invalidResponse("The Google refresh token is empty or too long.")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: googleRefreshTokenAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            attributes.forEach { insertion[$0.key] = $0.value }
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ClassWireAIError.invalidResponse("Could not save the Google refresh token in Keychain (error \(addStatus)).")
            }
        } else if status != errSecSuccess {
            throw ClassWireAIError.invalidResponse("Could not update the Google refresh token in Keychain (error \(status)).")
        }
    }

    static func loadGoogleRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: googleRefreshTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteGoogleRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: googleRefreshTokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

}
