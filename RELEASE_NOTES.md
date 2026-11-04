# Release Notes

## [2026.10.0-port.36]

### Navigation
- Use one typed NavigationSplitView selection for top-level destinations and individual course/group profiles.
- Give each selected sidebar destination its own detail-root identity so switching between courses, groups, Calendar, and other sections cannot reuse stale screen state.
- Keep pushed detail pages on the active destination's NavigationStack and clear that path when the sidebar destination changes.
- Apply the same navigation model on iOS and macOS, preserving native collapsed-sidebar behavior on iPhone.

### Build
- Increment the iOS and macOS build number to 36.


## [2026.10.0-port.35]

### Changed
- Share one recursive Resources browser between standalone Resources and group Resources, using the standalone list presentation in both places.
- Expand group resource folders inline and retain group-specific resource loading, refresh, and permission-gated Add Resource actions.
- Bump the project version to 2026.10.0-port.35.

## [2026.10.0-port.34]

### OAuth request signing
- Match Android and Classic Tauri's positive random 64-bit hexadecimal OAuth nonce format.
- Retain recent nonce values so a collision cannot replay a nonce during the current app session.

### Likes and profile navigation
- Selecting a person from a post's likes directory opens their profile in the main app navigation stack after dismissing the likes sheet.
- Selecting a person from a comment's likes directory dismisses both likes and comments presentations before opening the profile normally.

### Build
- Increment the iOS and macOS build number to 34.


## [2026.10.0-port.33]

### Switching to Schoology Classic
- Add a Settings action to discover the latest stable release from the official Schoology Classic Tauri repository.
- Select the architecture-matching macOS disk image or the iOS Ad Hoc installation manifest using the same platform asset conventions as Tauri port.28.
- Confirm before replacing the SwiftUI app; verify the downloaded macOS asset against GitHub's size and SHA-256 metadata before installing.
- Install Classic in place on macOS and use Apple's Ad Hoc OTA manifest flow on iOS/iPadOS.

### macOS navigation
- Increase the sidebar's preferred width while preserving native column resizing and a flexible range.

### Comment author resolution
- Extract author IDs from Schoology's nested user/profile fields and linked user/author/creator URLs.
- Recognize additional name and avatar fields from comment payloads, and avoid presenting the generic Schoology label as the author.


## [2026.10.0-port.32]

### Navigation and appearance
- Remove the redundant All Courses and All Groups destinations; expanding the sidebar now reveals each course and group directly.
- Use an appearance-aware Schoology blue that remains legible in dark mode across buttons, links, and notification icons.

### Posts, comments, and dialogs
- Use the signed-in user's profile image when rendering their own recent-activity posts and comments.
- Recognize additional embedded author, creator, name, and profile-image fields when decoding comments.
- Give macOS attachment and likes sheets useful minimum dimensions so actions are not clipped; use a full-height presentation on iOS.

### Assignment submissions
- Allow selecting and submitting multiple files in one pass.
- Show per-file upload progress and continue processing remaining files if one fails.


## [2026.10.0-port.31]

### Build and navigation
- Fix the missing assignment submission composer bindings that broke both iOS and macOS Actions builds.
- Add expandable Courses and Groups sections to the navigation sidebar, with direct links to individual profiles and All views.

### Rich content and attachments
- Preserve inline anchor links when converting Schoology HTML content for display.
- Render rich links in posts, messages, comments, assignment descriptions, teacher comments, and submission revisions.
- Route course-material file URLs through the shared View/Download attachment actions.


## [2026.10.0-port.30]

### Build reliability
- Fix assignment tab value inference and use the shared cross-platform inset-grouped list style for attachment sheets.

### Calendar and messages
- Reuse the homepage Upcoming event list and destinations in Calendar's Upcoming tab.
- Give each message in a conversation a stable, per-message identity even when Schoology repeats the containing thread ID.

### Resources and navigation
- Expand standalone resource folders recursively inline instead of navigating to separate folder pages.
- Animate folder contents when asynchronous loading completes, while respecting Reduce Motion.
- Remove the bundle identifier from Settings.


## [2026.10.0-port.29]

### Shared attachments
- Replace direct attachment previews with a compact shared Attachments sheet.
- Offer explicit View and Download actions for assignment, submission, comment, message, and post attachments.
- Add an assignment-level View Attachments action.

### Assignment submissions
- Move the student submission plus menu to the assignment navigation toolbar so it remains visible on iPhone.

### Shared WebView session
- Match the official Android/Tauri session bootstrap parameter name (`for_domain`).
- Install the required `s_mobile` cookie alongside server-issued session cookies.

### Build
- Increment iOS and macOS build number to 29.

# Release Notes

## [2026.10.0-port.28]

### Course Materials
- Expand course Materials folders inline, with nested folders loading only when opened.
- Keep the Materials list in place while navigating nested folder trees, with clear loading, empty, and retryable error states.

### Attachments
- Use the shared native Quick Look preview for message-thread attachments as well as existing comment and assignment attachments.

### App icon
- Complete the Schoology ring's missing lower-right outer arc so the iPhone icon renders as a continuous ring.

### Build
- Import the Quick Look framework explicitly for the shared preview modifier.
- Increment the iOS and macOS bundle build number to 28.

## [2026.10.0-port.27]

### Attachments
- Add authenticated downloads and a shared native Quick Look preview for comment attachments, assignment attachments, and submission revision attachments.
- Support common Schoology attachment formats, including PDFs, images, and Office documents, through the system preview experience.

### Build fixes
- Fix macOS resource picker title configuration by applying the inline title style only on iOS.
- Fix teacher grade editor error handling on both platforms.
- Sign teacher grade update requests with Schoology OAuth.
- Increment the iOS and macOS bundle build number to 27.

## [2026.10.0-port.26]

### Assignments
- Fix the assignment-submissions toolbar placement so the native toolbar compiles on macOS and remains a semantic primary action on iOS.
- Add Schoology resource selection and resource-based assignment submissions alongside file and text submissions.
- Allow teachers to open a student's grade editor and save grades, overall comments, and comment visibility.

### Build
- Increment the iOS and macOS bundle build number to 26.

## 2026.10.0-port.25
- Match official Tauri JSON request bodies for post and comment likes, and strengthen OAuth nonce uniqueness with a random-plus-sequence value.
- Ignore cancelled recipient-search requests instead of displaying a red error in the message composer.
- Show Schoology-style date and time labels on comments, keeping relative labels for posts from the last 24 hours.
- Hide the People directory unless the account's Schoology visibility permissions allow it, and move Sign Out to the bottom of the app sidebar.

## [2026.10.0-port.24]

### Authentication and post likes
- Refresh the Schoology server timestamp before signed write requests, bypass timestamp-response caching, and retain recently used OAuth nonces to prevent reuse.
- Match the Android OAuth nonce format and use the official plaintext signer for FileService uploads.

### Messages
- Prefer each message's message_id/messageId over a conversation-level id for SwiftUI identity, preventing repeated cards when Schoology returns a shared parent id.

### Grades
- Make linked assignment grade items open the native shared assignment detail page.

### Assignment submissions
- Add native SwiftUI file importing and upload progress feedback.
- Upload the selected file to Schoology FileService and create the submission with the official Android/Tauri files payload and assignment endpoint.
- Keep security-scoped file access scoped to the upload operation.

### App icon
- Reduce the Schoology mark scale within the square icon canvas so the ring has a clear safe margin.

### Build
- Increment the iOS and macOS bundle build number to 24.

## [2026.10.0-port.23]

### Authentication
- Generate OAuth nonces as fresh random 64-bit hexadecimal values, matching the official Android signer and Tauri port instead of using UUID-formatted values.

### Upcoming navigation
- Route homepage and other shared Upcoming assignment items into the native assignment detail page when Schoology supplies both section and assignment IDs.
- Route supported discussions, events, and assessments to their corresponding native or authenticated WebView destinations rather than a generic details placeholder.

### Assignment submissions
- Move student submission creation into a plus menu in the app bar, with text and upload actions.
- Keep text submissions connected to the native composer. The upload action clearly reports that file/resource upload is not wired yet.

### Build
- Increment the iOS and macOS bundle build number to 23.

## [2026.10.0-port.22]

### Build and app icon
- Fix the Swift key-path syntax that prevented both iOS and macOS archives from compiling.
- Generate the app icon from the exact Schoology ring and S vector paths in Tauri port.28.
- Provide matching light, dark, and tinted iOS/iPadOS and macOS icon appearances.

### Course and group loading
- Load group metadata and permissions first, then fetch each group tab only when selected.
- Cache successful group-tab responses and refresh only the selected tab on demand.
- Load course tabs lazily and cache successful responses, including Course Apps; keep the wide-layout Upcoming panel independently lazy.

### Build
- Increment the iOS and macOS bundle build number to 22.

## [2026.10.0-port.21]

### Assignments and submissions
- Derive assignment teacher, discussion, and submission permissions from official Schoology assignment, section, enrollment, and grade-item responses.
- Show Info on every assignment, Comments only when discussion is allowed, and Submissions only when dropbox/submission is enabled.
- Use a dedicated submissions pane on wide layouts only when submissions are enabled; use native SwiftUI tabs for compact assignment navigation, following Apple's guidance to use tab views for primary content switching.
- Add student submission history, teacher roster submission status, and native text-submission posting through the official Tauri JSON endpoint and query parameters.
- Route LTI submissions into the authenticated embedded Schoology WebView.

### Messages
- Remove the duplicate Messages refresh action and add a Compose Message toolbar action.
- Add recipient lookup and native message composition using the official `messages/recipients` and `messages` endpoints.
- Give the conversation thread a full-height, eagerly measured scrolling stack and pull-to-refresh.

### Course Apps
- Allow JavaScript popup/window.open requests and route target=_blank navigation into the same authenticated WebView.

### Grades
- Limit numeric grade, percentage, and points display to two fractional digits.
- Indent assignment rows as well as grading categories so each nested gradebook level is visually distinct.

### Build
- Increment the iOS and macOS bundle build number to 21.

## [2026.10.0-port.20]

### Grades
- Restore the official grading-period → grading-category → assignment hierarchy in standalone Grades and course Grades.
- Keep gradebook rows, category weights, scores, due dates, and teacher comments grouped in native SwiftUI disclosure controls.
- Preserve the final grade and teacher comment while avoiding arbitrary selection of another student's grade record.

### Performance
- Replace serial group-update author profile lookups with the existing bounded-concurrency profile loader.
- Hydrate missing author names and avatars in parallel while preserving any author data already embedded in the activity response.

### Build
- Increment the iOS and macOS bundle build number to 20.

## [2026.10.0-port.19]

### Standalone Schoology pages
- Add a native Resources destination with My Resources, Shared, Groups, and Resource Apps categories, collection browsing, folder navigation, and authenticated resource links.
- Add a standalone Grades destination with course grade summaries and expandable course grade-item details, reusing the corrected course-grade API implementation.
- Add a standalone Calendar destination with month navigation, event-day indicators, selected-day details, and an Upcoming view.
- Base Schoology API paths and response fields on the official Android 2026.10.0 source and classic Tauri port.28 implementation.

### Build
- Remove the unmatched closing brace in SchoologyModels.swift that prevented both iOS and macOS targets from compiling.
- Increment the iOS and macOS bundle build number to 19.

## [2026.10.0-port.18]

### Notifications
- Decode the notification envelope, `notification` list, `body_args` links, `realm_id`, viewed state, and Unix timestamps using the official Android response model.
- Render notification text with related Schoology items rather than a stringified `body_args` array.
- Add notification detail navigation for assignments, discussions, events, documents, pages, groups, schools, sections, users, and albums.
- Mark notifications read only after the first response reports an unviewed count, matching Android behavior.
- Add initial loading, explicit empty/error states, pull-to-refresh, and paginated loading of older notifications.

### macOS build and appearance
- Correct the tab-picker availability gate: `.tabs` requires macOS 27, not macOS 26.
- Keep segmented navigation on earlier macOS versions and apply a Liquid Glass surface on macOS 26.
- Increment the iOS and macOS bundle build number to 18.

## [2026.10.0-port.17]

### Authentication and course navigation
- Match the official Android `sessionstart?domain=` web-session bootstrap and scope returned cookies to the Schoology parent domain.
- Open Course Apps directly from their signed v2 launch URLs without an unnecessary cookie bootstrap.
- Route course-material assignments, discussions, events, assessments, folders, and linked resources to their matching native or authenticated destinations.
- Load course Grades using the official course grade-items, grading-period, grading-category, and per-user grade requests instead of the forbidden generic section grades request.
- Send discussion and assignment comments with the official `comment` and `parent_id` fields.

### Interface
- Use macOS 26's tab-specific picker style for navigation pickers while retaining the segmented fallback on earlier macOS releases.
- Add a Liquid Glass surface to post actions, an explicit close control to the comments sheet, and a full-height likes directory.
- Make the course sidebar independently scrollable and correct the course-tab loading/error text interpolation.
- Repair the School profile API path interpolation introduced in the previous release.

### Build
- Increment the iOS and macOS bundle build number to 17.

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
