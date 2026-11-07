# ClassWire — Native SwiftUI

A native ClassWire client for **macOS, iPhone, and iPad**, built for Schoology courses and communication.

## Reference implementations

Schoology-specific behavior is grounded in the supplied source projects:

- **Schoology Desktop Port `2026.10.0-port.28`** — desktop interaction patterns, navigation, attachment behavior, and established Tauri-host workflows.
- **Official Schoology Android `2026.10.0` source** — API models and endpoints, OAuth request signing, cookie/session forwarding, resource-app imports, and native Schoology behavior.

The app is a native SwiftUI implementation. It does not embed the Tauri renderer or use Electron.

## Platforms and identity

| Platform | Minimum deployment target |
| --- | --- |
| iPhone and iPad | iOS 18 |
| Mac | macOS 14 |

- App name: **ClassWire**
- Bundle identifier: `com.schoologytauri.app` on iOS and macOS
- Swift language mode: Swift 6
- Native UI: SwiftUI, with platform frameworks such as WebKit and AVKit where appropriate
- Credentials: stored in the platform Keychain

## Implemented functionality

The project is an incremental native port. The following areas have native implementations in the current source:

### Sign-in and account

- School search and school selection.
- Username/email and password sign-in.
- School single-sign-on browser handoff and callback.
- QR-code sign-in.
- OAuth 1.0 HMAC-SHA1 request signing and token exchange.
- Canadian Schoology environment selection.
- Session restoration and authenticated Schoology web-session cookie retrieval.

### Home and navigation

- Adaptive native navigation: compact navigation on iPhone and split/sidebar layouts on regular-width iPad and macOS.
- Home recent activity, course dashboard, and Upcoming.
- Courses, groups, and school/person profile destinations.
- System, light, and dark appearance settings.
- Reduced-motion-aware app-shell transitions and native platform presentation behavior.

### Schoology content

- Recent activity posts with author information, attachments, likes, and comments.
- Native comment threads, replies, and like actions.
- Course, group, school, and person profile views.
- Course materials, nested folders, pages, and course applications.
- Schoology Resources browsing, shared/group collections, and Resource Apps.
- Resource App importing, including files and links returned through the Schoology mobile import flow.
- Assignments, assignment details, submissions, teacher/student submission views, and grading.
- Gradebook and overall-grade summaries, including supported teacher overrides.
- Calendar, Upcoming events, discussions, and event details.
- Messages with Inbox, Unread, and Sent folders, message details, attachments, and composing.
- Notifications, notification preferences, and native push-notification registration support.

### Attachments and media

- Shared attachment actions for viewing and downloading.
- Native document/image preview and export flows.
- Schoology-converted PDF previews when conversion is available and appropriate for the file type.
- Original-file downloads that retain the attachment's filename and extension.
- Native AVKit playback UI for common audio and video formats supported by the operating system.
- Authenticated attachment requests with Schoology session cookies and redirect handling.

Actual playback depends on the file's encoding and the media codecs supported by the installed version of iOS or macOS. A listed container or extension does not guarantee that every codec will play.

### Appearance and accessibility

- System-aware light and dark appearance.
- Native SwiftUI controls, navigation, sheets, and platform conventions.
- Dynamic Type-friendly layouts and accessibility labels on interactive controls.
- Reduced-motion-aware shell transitions.

Some Schoology capabilities and specialized content types are not yet implemented. The presence of an area in this list does not imply that every Schoology endpoint, file format, or edge case is supported.

## Build and release process

GitHub Actions is responsible for building, signing, and packaging the app. Do not rely on local build output as a release artifact.

- **macOS:** universal Apple Silicon/Intel app, Developer ID signing, notarization, and DMG packaging.
- **iOS/iPadOS:** signed Ad Hoc IPA for registered devices.
- A versioned GitHub Release is published when at least one platform package succeeds.

The current release version is stored in `VERSION`. Increment the `-port.N` suffix for each release and add a matching section at the top of `RELEASE_NOTES.md`. The Xcode project configuration maps the numeric port value to the Apple build number while keeping the complete version in GitHub release tags.

### Updating the app

- **iOS/iPadOS:** the update action opens Apple's Ad Hoc installation flow using the release manifest. The device must be registered and the user must confirm installation; iOS does not permit an app to silently replace itself.
- **macOS:** the update action opens the signed DMG for installation.

## GitHub Actions signing configuration

The release workflow expects the following repository secrets/variables:

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

Never commit signing credentials, private keys, provisioning profiles, or generated certificates to the repository.

## Repository layout

- `Sources/` — SwiftUI screens, Schoology models/API, session management, and platform integrations.
- `Resources/Assets.xcassets/` — app icons and bundled image assets.
- `Config/` — platform entitlements and generated Info.plist configuration.
- `.github/workflows/build.yml` — signed CI build and release workflow.
- `VERSION` — current port release version.
- `RELEASE_NOTES.md` — user-facing release history.
