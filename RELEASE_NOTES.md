# Schoology SwiftUI Release Notes

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
