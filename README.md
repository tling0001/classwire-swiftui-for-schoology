# Schoology — Native SwiftUI

A native SwiftUI port of Schoology for macOS, iOS and iPadOS.

## Reference sources

- Schoology Desktop Port `2026.10.0-port.28` for established desktop behavior, app navigation, and Tauri-host functionality.
- Official Schoology Android `2026.10.0` source for API contracts, OAuth signing, Canadian environment configuration, and native login behavior.

Schoology-specific implementation is grounded in those supplied sources rather than unofficial web descriptions.

## Platforms and identity

- iOS / iPadOS deployment target: iOS 18+
- macOS deployment target: macOS 15+
- App display name: **Schoology**
- Bundle identifier on both targets: `com.schoologytauri.app`
- SwiftUI is the primary UI framework. Schoology content is requested through the native API client.

## Current implementation

- Native SwiftUI app targets for macOS and iOS/iPadOS.
- Native sidebar navigation that collapses to the standard iPhone navigation stack; regular-width iPad and macOS retain a split sidebar/detail layout.
- School search, username/email credential login, school SSO browser handoff, and QR-code login.
- OAuth 1.0 HMAC-SHA1 signing and redirect handling aligned with the official Tauri implementation and Android request-signing behavior.
- Canadian Schoology host and OAuth credentials, with the server choice persisted across launches.
- OAuth credentials stored in the platform Keychain.
- Home recent activity posts, course dashboard, upcoming events, Courses, and Groups.
- Native appearance settings, system/light/dark theme support, and reduced-motion-aware shell transitions.
- iOS and macOS app icons compiled from the app icon asset catalogs, with an iOS CI check for the exported primary-icon metadata generated from the asset catalog.

This is an incremental native port. Messages, notifications, requests, resources, grades, calendar, course/group detail pages, assignment submission, PDF annotation, and push notifications remain to be ported.

## Builds and releases

GitHub Actions builds the native macOS app as a universal Apple Silicon/Intel Developer ID package, notarizes the app and DMG, and exports a signed iOS Ad Hoc IPA for registered devices. A versioned GitHub Release is published whenever at least one platform package succeeds.

The release version is stored in `VERSION` as `2026.10.0-port.4`. Increment the `-port.N` value for each new port release and add a matching `## [version]` section to `RELEASE_NOTES.md`. The workflow uses the numeric marketing version and port number as the Apple bundle version/build number, while GitHub release tags retain the complete `-port.N` suffix.

The iOS update action opens Apple's `itms-services` installation flow for the Ad Hoc manifest. iOS requires a registered device and user confirmation; the app cannot silently replace itself. On macOS, Download Update opens the signed DMG for the user to install.

## Apple signing configuration

Required GitHub secrets/variables are:

- `APPLE_TEAM_ID`
- `APPSTORE_API_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_API_PRIVATE_KEY`
- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Do not commit signing credentials, provisioning profiles, or private keys to the repository.
