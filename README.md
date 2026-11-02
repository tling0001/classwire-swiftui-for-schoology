# Schoology — Native SwiftUI

A native SwiftUI port of Schoology for macOS, iOS and iPadOS.

## Reference sources

- Schoology Desktop Port `2026.10.0-port.28` for established desktop behavior, app navigation, and Tauri-host functionality.
- Official Schoology Android `2026.10.0` source for API contracts, OAuth signing, Canadian environment configuration, and native login behavior.

Schoology-specific implementation should be grounded in those supplied sources rather than unofficial web descriptions.

## Platforms and identity

- iOS / iPadOS deployment target: iOS 18+
- macOS deployment target: macOS 15+
- App display name: **Schoology**
- Bundle identifier on both targets: `com.schoologytauri.app`
- SwiftUI is the primary UI framework. Schoology content is requested through the native API client, not rendered inside a Tauri/Electron shell.

## Current implementation

- Native SwiftUI app targets for macOS and iOS/iPadOS.
- Adaptive navigation: macOS and regular-width iPad use a sidebar/detail split view; iPhone uses native tabs.
- School search and username/email credential login.
- OAuth 1.0 HMAC-SHA1 signing aligned with the Tauri implementation and official Android URL-encoding behavior.
- Canadian Schoology host and OAuth credentials, with the server choice persisted across launches.
- OAuth credentials stored in the platform Keychain.
- Initial Home recent-activity, Courses, and Groups data loading.
- Native appearance settings, system/light/dark theme support, and reduced-motion-aware shell transitions.
- macOS menu commands and keyboard shortcuts.

This is the first implementation milestone, not a feature-complete port. District SSO/browser handoff, QR login, messages, notifications, requests, resources, grades, calendar, course/group detail pages, assignment submission, PDF annotation, push notifications, and signed release packaging remain to be ported.

## Build locally

Install Xcode and XcodeGen, then:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Schoology.xcodeproj -scheme Schoology-macOS -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Schoology.xcodeproj -scheme Schoology-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

GitHub Actions performs unsigned macOS and iOS Simulator build validation. Local builds are not part of the current project workflow.

## Apple signing configuration

For later signed distribution, the repository will use:

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

The certificate-generation helper inputs `MACOS_CERTIFICATE_PRIVATE_KEY_PEM_BASE64` and `MACOS_DEVELOPER_ID_CERTIFICATE_CER_BASE64` are retained for certificate automation. `APP_STORE_CONNECT_CERTIFICATE_ID` is an App Store Connect certificate resource identifier, not the API key ID.

Do not commit signing credentials, provisioning profiles, or private keys to the repository.
