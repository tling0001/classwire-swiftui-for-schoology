import Foundation
import Security

/// Generates OAuth nonces once per app process, shared by every SchoologyAPI actor.
/// The format mirrors the Tauri signer: 128 random bits plus a process-wide UInt64 sequence.
actor OAuthNonceGenerator {
    static let shared = OAuthNonceGenerator()

    private var counter: UInt64 = 0
    private var recentNonces = Set<String>()
    private var nonceOrder: [String] = []

    func nextNonce() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 16)
        let randomStatus = randomBytes.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }

        let randomPart: String
        if randomStatus == errSecSuccess {
            randomPart = randomBytes.map { String(format: "%02x", $0) }.joined()
        } else {
            randomPart = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }

        var nonce = ""
        repeat {
            counter &+= 1
            nonce = randomPart + String(format: "%016llx", CUnsignedLongLong(counter))
        } while recentNonces.contains(nonce)

        recentNonces.insert(nonce)
        nonceOrder.append(nonce)
        if nonceOrder.count > 8192 {
            let expired = nonceOrder.removeFirst()
            recentNonces.remove(expired)
        }
        return nonce
    }
}
