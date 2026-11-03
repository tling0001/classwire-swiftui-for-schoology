# Schoology SwiftUI Release Notes

## [2026.10.0-port.4]

### Fixed
- Corrected iOS Ad Hoc export validation to inspect the primary icon name at `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName`, the location populated by Xcode's asset catalog compiler.
- Removed the manually injected top-level `CFBundleIconName` value so each platform target uses its own configured app icon asset catalog.

## [2026.10.0-port.3]

### Sign-in
- Rebuilt sign-in with native SwiftUI button styles, system backgrounds, adaptive light/dark colors, and the same Schoology action labels.
- Updated the Schoology wordmark treatment and made sign-in controls respond to system appearance.

### Home
- Fixed recent activity decoding to handle the official `recent` response wrappers and update-list shapes.
- Added author and attachment parsing for activity posts.
- Added the Home Recent Activity, Course Dashboard, and Upcoming sections.
- Added course images, school names, and course-specific upcoming events.

### Navigation and app icon
- Replaced the compact iPhone tab bar with a native NavigationSplitView sidebar that collapses into the standard iPhone navigation stack.
- Added an iOS release validation step that verifies the exported app references the AppIcon catalog and contains compiled assets.

## [2026.10.0-port.2]

### Fixed
- Match the QR authorization endpoint and request signing to the official Tauri 2026.10.0-port.28 implementation.
- Re-sign Schoology API requests after same-host HTTPS redirects instead of replaying a stale OAuth Authorization header.
- Verify the access token once before saving it, and store the verified Schoology user ID.

### Changed
- Align the native sign-in screens, labels, logo treatment, and action buttons with the official Tauri sign-in experience.
- Add the Schoology ring-and-S app icon for macOS and iOS, including iOS dark and tinted appearances.
- Increment the native port release to 2026.10.0-port.2.

## [2026.10.0-port.1]

### Added
- Establish the first native SwiftUI port release version.
- Add GitHub Actions packaging for universal macOS Developer ID distribution and iOS Ad Hoc installation.
- Publish signed and notarized macOS DMG/ZIP assets.
- Publish the registered-device iOS Ad Hoc IPA, installation manifest, and QR code.
- Add automatic startup update checks and a manual Software Update section in Settings.
- Add version-specific GitHub release notes.

### Changed
- Reset the SwiftUI port release sequence to `2026.10.0-port.1`.
- Keep the `com.schoologytauri.app` bundle identifier for continuity with the existing Ad Hoc App ID and provisioning profile.
