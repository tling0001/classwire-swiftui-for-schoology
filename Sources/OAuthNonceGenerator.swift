import Foundation
import Security

/// Generates OAuth nonces once per app process, shared by every SchoologyAPI actor.
/// The format mirrors the Tauri signer: 128 random bits plus a process-wide UInt64 sequence.
actor OAuthNonceGenerator {
    static let shared = OAuthNonceGenerator()

    // One cryptographically random prefix per process, followed by a strictly
    // increasing sequence. This matches the Tauri signer's nonce structure.
    private let processPrefix: String
    private var counter: UInt64 = 0

    init() {
        var randomBytes = [UInt8](repeating: 0, count: 16)
        let randomStatus = randomBytes.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }
        if randomStatus == errSecSuccess {
            processPrefix = randomBytes.map { String(format: "%02x", $0) }.joined()
        } else {
            processPrefix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
    }

    func nextNonce() -> String {
        precondition(counter < UInt64.max, "OAuth nonce sequence exhausted")
        counter += 1
        return processPrefix + String(format: "%016llx", CUnsignedLongLong(counter))
    }
}
