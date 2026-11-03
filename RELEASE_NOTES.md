# Schoology SwiftUI Release Notes

## [2026.10.0-port.16]

### School profile posts
- Render school updates through the shared native activity-post card so school posts have the same comments, replies, likes, and likes directory as home, course, and group posts.
- Resolve school post comments against the official `schools/{schoolId}/updates/{updateId}/comments` route.
- Hydrate school update authors using the same bounded profile lookup used by other activity feeds.

### Quality
- Remove the unused optional binding warning in the shared comments composer.
- Increment the iOS and macOS bundle build number to 16.

## [2026.10.0-port.15]

### Shared comments and likes
- Add one reusable native comments sheet for update posts, with nested replies, author-profile navigation, attachments, and a composer.
- Add a shared likes directory for posts and individual comments.
- Support post Like / Unlike, comment Like / Unlike, reply actions, and live count updates.
- Use the official update comments, like, and comment-like API routes with OAuth-signed requests.
- Add realm metadata to recent activity and explicitly scope course/group update posts to their owning section or group.

### Build
- Increment the iOS and macOS bundle build number to 15.

## [2026.10.0-port.14]

### Home and dashboard
- Track initial activity, course, and upcoming requests independently so empty states appear only after the corresponding request finishes.
- Show distinct loading and request-error states for Recent Activity, Course Dashboard, and Upcoming.
- Keep existing data visible during refreshes rather than flashing empty states.

### Layout and appearance
- Standardize course, group, and school sidebar hero images to centered 4:3 frames with bounded clipping.
- Constrain dashboard course artwork to its card's actual width and height so panoramic images cannot expand or overlap neighboring cards.
- Improve macOS dark-mode Settings controls with a brighter adaptive accent and a prominent Check for Updates button.
- Add a loading state to the course Upcoming sidebar.

### Build
- Increment the iOS and macOS bundle build number to 14.

## [2026.10.0-port.13]

### Messages
- Hydrate distinct message participants concurrently with a six-request limit instead of serial user lookups.
- Reuse author profiles already included in message-thread responses and only request missing users.
- Preserve nested author/sender names and avatars when decoding conversation messages.
- Keep all decoded conversation messages and attachments in the existing native thread view.

### Build
- Increment the iOS and macOS bundle build number to 13.

## [2026.10.0-port.12]

### Course Apps and People
- Remove the unsupported Assignments course-profile tab; assignments remain accessible from official activity and upcoming-item destinations.
- Restore Course Apps separately from core course sections, filter `@extra` entries through the `@items` relationship, and use validated OAuth-signed v2 launch links.
- Add native pushed Course App destinations backed by the authenticated WebKit session.
- Reuse one searchable, alphabetically grouped People directory for course members, group members, and the People destination, including All / Members / Admins filters and administrator badges.
- Prefer enrollment user IDs over enrollment record IDs when decoding member profiles.

### Build
- Increment the iOS and macOS bundle build number to 12.

## [2026.10.0-port.11]

### Adaptive wide-screen layouts
- Add a Tauri-inspired two-pane homepage with Upcoming alongside Recent Activity or Course Dashboard on wide iPad and Mac windows.
- Add a three-pane course layout with course identity and section navigation, selected section content, and Upcoming.
- Make group and school profile panes use proportional widths and a wider-screen breakpoint.
- Keep compact iPhone layouts stacked with segmented section navigation.

### Build workflow
- Move iOS and macOS release jobs to the Apple Silicon Xcode 27 runner image.
- Select Xcode 27.2 explicitly and fail early unless both iOS and macOS SDK 27.2 are available.


## [2026.10.0-port.10]

### Groups, posts, and profiles
- Reuse the same shared recent-activity post cards for group updates, including authenticated author images and attachments.
- Add native group discussion, event, album, resource-folder, and member-profile navigation.
- Add a dedicated searchable Groups screen.

### Assignments, courses, and upcoming
- Add native course sections for Materials, Assignments, Updates, Grades, Members, and Upcoming.
- Add native assignment details and discussion/event detail pages with comment threads and reply posting.
- Route upcoming items into the matching native detail page where Schoology provides the relevant IDs.

### Messages and account
- Decode complete message threads and show each author's profile image beside their name.
- Add Account Info in Settings using the authenticated Schoology shared WebKit session.
- Fix the macOS resource composer keyboard modifier so the iOS-only keyboard configuration is excluded from macOS compilation.

## [2026.10.0-port.9]

### Groups and schools
- Add permission-gated native group actions for updates, discussions, events, albums, and resource attachment using the official Tauri request parameters.
- Make group and school profile rows open native detail sheets, retaining any supplied attachment or resource link.
- Keep school profile tabs and the group-to-school navigation available across compact and wide layouts.


## [2026.10.0-port.8]

### Added
- Add native Messages with Inbox, Unread (derived from inbox message status), and Sent folders, thread loading with attachments, and an adaptive wide-screen split layout.
- Add native Notifications using the confirmed notifications endpoint and mark notifications read when Schoology reports unviewed items.
- Add a signed-in Profile destination to the navigation sidebar.


## [2026.10.0-port.7]

### Changed
- Use native Liquid Glass button styles for login actions on iOS 26 and macOS 26, retaining bordered fallbacks on earlier systems.
- Remove the decorative course initial that previously overlaid course dashboard images.

### Fixed
- Use NavigationSplitView selection for compact sidebar navigation so destination changes and returning to the sidebar use the system navigation stack and animation.
- Load Schoology-hosted avatars and post images through authenticated image requests, matching the Tauri host's signed image-fetch behavior.
- Preserve inline rich-text image URLs and image attachment URLs when decoding recent activity posts.

## [2026.10.0-port.6]

### Fixed
- Add the asset catalog directly to each app target's resource build phase so Xcode compiles it into the iOS and macOS applications.
- Remove manually injected iOS primary-icon metadata and let the asset catalog compiler generate the authoritative CFBundleIcons entries.
- Validate the compiled asset catalog before validating the primary icon metadata.
- Align the fallback Xcode build number with port.6.


## [2026.10.0-port.5]

### Fixed
- Correct the iOS primary icon metadata in the generated Info.plist so the app points to the AppIcon asset catalog.
- Validate the exported icon from the compiled Assets.car using Apple's assetutil, including the 1024x1024 primary rendition.
- Keep the Xcode project fallback build number aligned with the port release number.


## [2026.10.0-port.4]

### Fixed
- Corrected iOS Ad Hoc export validation to inspect the primary icon name at CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName, the location populated by Xcode's asset catalog compiler.
- Removed the manually injected top-level CFBundleIconName value so each platform target uses its own configured app icon asset catalog.

## [2026.10.0-port.3]

### Sign-in
- Rebuilt sign-in with native SwiftUI button styles, system backgrounds, adaptive light/dark colors, and the same Schoology action labels.
- Updated the Schoology wordmark treatment and made sign-in controls respond to system appearance.

### Home
- Fixed recent activity decoding to handle the official recent response wrappers and update-list shapes.
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
- Reset the SwiftUI port release sequence to 2026.10.0-port.1.
- Keep the com.schoologytauri.app bundle identifier for continuity with the existing Ad Hoc App ID and provisioning profile.
