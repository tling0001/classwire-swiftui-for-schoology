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
    private var pendingContinuation: CheckedContinuation<URL, Error>?
    private var isCancelling = false

    #if os(macOS)
    private var fallbackPresentationWindow: NSWindow?
    #endif

    func cancel() {
        isCancelling = true
        activeSession?.cancel()
    }

    func authenticate(using url: URL) async throws -> URL {
        guard !isCancelling else {
            isCancelling = false
            throw CancellationError()
        }
        guard activeSession == nil, pendingContinuation == nil else {
            throw SchoolBrowserAuthenticatorError.authenticationAlreadyInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            let completionHandler = Self.makeCompletionHandler(for: self)
            let session: ASWebAuthenticationSession
            #if os(macOS)
            if #available(macOS 14.4, *) {
                session = ASWebAuthenticationSession(
                    url: url,
                    callback: .customScheme("schoology"),
                    completionHandler: completionHandler
                )
            } else {
                session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "schoology",
                    completionHandler: completionHandler
                )
            }
            #else
            session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme("schoology"),
                completionHandler: completionHandler
            )
            #endif
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session

            guard session.start() else {
                finish(.failure(SchoolBrowserAuthenticatorError.unableToStart))
                return
            }
        }
    }

    // AuthenticationServices calls this handler from Safari's XPC queue.
    // Keep the handler nonisolated and hop to MainActor before touching state.
    private nonisolated static func makeCompletionHandler(
        for authenticator: SchoolBrowserAuthenticator
    ) -> ASWebAuthenticationSession.CompletionHandler {
        { [weak authenticator] callbackURL, error in
            Task { @MainActor [weak authenticator] in
                guard let authenticator else { return }
                authenticator.handleAuthenticationCompletion(callbackURL: callbackURL, error: error)
            }
        }
    }

    private func handleAuthenticationCompletion(callbackURL: URL?, error: Error?) {
        if isCancelling {
            finish(.failure(CancellationError()))
        } else if let error {
            finish(.failure(error))
        } else if let callbackURL {
            finish(.success(callbackURL))
        } else {
            finish(.failure(SchoolBrowserAuthenticatorError.missingCallback))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        activeSession = nil
        isCancelling = false
        #if os(macOS)
        fallbackPresentationWindow = nil
        #endif
        continuation.resume(with: result)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
        #else
        if let window = NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: \.isVisible) {
            return window
        }
        let anchor = fallbackPresentationWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        fallbackPresentationWindow = anchor
        return anchor
        #endif
    }
}

private enum SchoolBrowserAuthenticatorError: LocalizedError {
    case missingCallback
    case unableToStart
    case authenticationAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .missingCallback: "School sign-in did not return an authorization callback."
        case .unableToStart: "The secure school sign-in browser could not be started."
        case .authenticationAlreadyInProgress: "A school sign-in session is already in progress."
        }
    }
}
