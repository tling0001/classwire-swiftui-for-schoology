import Foundation

enum SchoologyDeepLinkRouter {
    private static let scheme = "schoology"

    static func isAuthenticationCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme
            && url.host?.lowercased() == "external_login_callback"
    }

    /// Resolves the link handoff emitted by the Classic Chrome link handler.
    /// Only ordinary HTTP(S) destinations are eligible for system URL opening.
    static func externalLinkDestination(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == "link",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawDestination = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let destinationComponents = URLComponents(string: rawDestination),
              let destinationScheme = destinationComponents.scheme?.lowercased(),
              destinationScheme == "https" || destinationScheme == "http",
              let host = destinationComponents.host,
              !host.isEmpty,
              destinationComponents.user == nil,
              destinationComponents.password == nil,
              let destination = destinationComponents.url else {
            return nil
        }

        return destination
    }
}
