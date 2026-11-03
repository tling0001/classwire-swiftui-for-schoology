import AuthenticationServices
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class SchoolBrowserAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?
    private var isCancelling = false

    func cancel() {
        isCancelling = true
        activeSession?.cancel()
    }

    func authenticate(using url: URL) async throws -> URL {
        if isCancelling {
            isCancelling = false
            throw CancellationError()
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme("schoology")
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    let wasCancelledByApp = self?.isCancelling == true
                    self?.isCancelling = false
                    self?.activeSession = nil
                    if wasCancelledByApp {
                        continuation.resume(throwing: CancellationError())
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: SchoolBrowserAuthenticatorError.missingCallback)
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            if !session.start() {
                activeSession = nil
                continuation.resume(throwing: SchoolBrowserAuthenticatorError.unableToStart)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
        #else
        NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow()
        #endif
    }
}

private enum SchoolBrowserAuthenticatorError: LocalizedError {
    case missingCallback
    case unableToStart

    var errorDescription: String? {
        switch self {
        case .missingCallback: "School sign-in did not return an authorization callback."
        case .unableToStart: "The secure school sign-in browser could not be started."
        }
    }
}
