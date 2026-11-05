## [2026.10.0-port.59]

### Course Materials
- Let folder descriptions wrap to their full height instead of truncating after one line.
- Use compact native macOS material rows while retaining touch-friendly 44-point rows on iPhone and iPad.
- Replace the folder disclosure label with a full-row accessible toggle and center its chevron against the complete row content.

### Recent Activity
- Publish Recent Activity as soon as its own request finishes instead of waiting for course, group, and upcoming requests.
- Move optional author-profile hydration off the initial refresh path and merge only missing author details into the current feed.

### Likes
- Add an explicit macOS Close button to the Likes sheet.

### Build
- Increment the iOS and macOS bundle build number to 59.

## [2026.10.0-port.58]

### Course Materials
- Open file-type course materials directly into the shared View / Download attachment actions instead of pushing a blank intermediate page.
- Apply the same direct attachment behavior inside recursively expanded course folders; keep link-type materials opening in the authenticated web view.

### Software Updates
- Surface available updates at launch with a non-blocking, adaptive in-app banner containing the same “Update available”, “Later”, and “Install update” wording as the desktop ports.
- Remember a per-release Later choice so the same update does not repeatedly interrupt subsequent launches.
- Route the launch banner and Settings install button through one shared platform-specific installer implementation.
- Keep iOS Ad Hoc installation and the verified macOS DMG replacement handoff in the shared update service.

### Build
- Increment iOS and macOS bundle build number to 58.

## [2026.10.0-port.57]

### Course Materials and attachments
- Remove the oversized macOS control-size override from course material rows.
- Replace the shared “View Attachments” button with an inline attachment list; selecting an attachment opens its own View and Download actions.

### Navigation
- Reset the selected detail root's identity when the macOS sidebar selection changes so the newly selected course reloads its own content and state.

### Grades
- Hydrate standalone course overall grades from section final-grade records, matching the signed-in user's enrollment as in the Android/Tauri implementation.
- Respect Schoology's custom overall-grade setting and display text or numeric overrides when enabled; otherwise use the calculated final-period grade.
- Resolve the final grading period and grading scale from the matching enrollment record, including letter-grade display and teacher comments.

### Build
- Increment iOS and macOS bundle build number to 57.

# Release notes

## [2026.10.0-port.56]

### Build fix
- Split course document attachment and link URL parsing into explicitly typed intermediate lookups to resolve Swift compiler type-check timeouts on iOS and macOS.
- Preserve attachment URL precedence, converted-preview behavior, and link destination fallback.

### Build
- Increment iOS and macOS build number to 56.

## [2026.10.0-port.55]

### Course materials and attachments
- Resolve course document materials through the official section document endpoint and read nested file attachments, matching the Tauri port's material lookup.
- Open the native View / Download actions directly when a course material is a file, including files whose download URL is supplied only by the document detail response.
- Preserve converted preview URLs only when Schoology reports successful conversion, and keep the original file URL for downloads.
- Forward the Schoology mobile cookie through HTTPS file redirects while keeping OAuth authorization restricted to the configured API host.

### Posts
- Label one or two post comments explicitly as Comments (1) and Comments (2).

### Build
- Increment the iOS and macOS build number to 55.

## [2026.10.0-port.54]

### macOS build fix
- Compile the ephemeral notification authorization status check only on iOS; macOS now checks authorized and provisional states supported by its UserNotifications SDK.
- Keep iOS ephemeral authorization support unchanged.
- Increment the iOS and macOS build number to 54.

## [2026.10.0-port.53]

### Build fixes
- Restore the shared push-registration notification name used by the notification service and Settings view, fixing the iOS Swift compilation errors.
- Select the active macOS Developer ID provisioning profile by its Apple-reported profile type instead of assuming a fixed profile name.
- Validate the selected profile's production APNs entitlement and pass its actual name to archive and export signing.
- Increment the iOS and macOS build number to 53.

## [2026.10.0-port.52]

### Push notifications
- Fix Swift 6 actor-isolation errors by passing immutable JSON data across the Schoology API actor boundary.
- Enable native macOS APNs registration and foreground/tap handling.
- Stop persisting APNs device tokens; request a fresh token from Apple at launch and retain it only in memory.
- Add macOS notification permission, enable/disable, sound, and registration-error controls.
- Sign and export the macOS app with a Developer ID provisioning profile carrying the production APNs entitlement.
- Follow the Android registration sequence: GET token status, PUT an inactive registration, or POST when the status lookup fails.

### CI
- Validate the Developer ID provisioning profile and its APNs entitlement before archiving.
- Map the Developer ID profile into the notarized app export options.

## [2026.10.0-port.51]

### Notifications
- Match Schoology's Android registration sequence by checking APNs device-token status with POST before updating it with PUT.
- Retain APNs tokens received before sign-in and register them after session restore or sign-in.
- Surface APNs registration failures in notification settings instead of silently ignoring them.
- Unregister the device token when the signed-in account signs out.
- Keep macOS push delivery explicitly unavailable until the Developer ID target has the required APNs provisioning.

### Assignments and discussions
- Fix assignment comments loading and posting by using the section assignment comments endpoint used by Tauri.
- Normalize singular Schoology realm names before discussion and event comment requests.
- Send discussion and event comments using the JSON request body used by Tauri.

### Events
- Replace the combined event/comment screen with native Info and conditional Comments tabs.
- Respect Schoology's `comments_enabled` flag, preserve the event's rich HTML description, and show event attachments and date details.
- Reuse the shared comments thread for author details, replies, and attachments.

### Rich text and messages
- Preserve assignment descriptions and teacher comments as HTML so the shared rich-text renderer retains links, emphasis, and font styling.
- Fix message attachment uploads by sending the selected file's actual MIME type in the multipart file part.

### Build
- Increment the iOS and macOS bundle build number to 51.

## [2026.10.0-port.50]

### Upcoming
- Reuse the shared Upcoming event list and destination router in course, group, and school profiles on compact and wide layouts.
- Route group and school discussions/events through their owning profile context while preserving course and assignment destinations.

### Course materials
- Let iPhone and iPad course-material folder rows use their natural SwiftUI height instead of imposing a fixed minimum row height.

### Grades
- Match the Tauri gradebook's teacher-override behavior for final grades, including explicit letter/percentage overrides, numeric overrides, grading-scale letter conversion, and hide-numeric scales.
- Resolve the signed-in student's final-grade record by enrollment instead of selecting another student's record.

### Build
- Increment the iOS and macOS bundle build number to 50.

## [2026.10.0-port.49]

### Calendar and discussions
- Reuse the Upcoming event list and detail router in Calendar's selected-day split, including quiz, assignment, discussion, event, and LTI destinations.
- Add native Info and Discussion tabs to discussion details.
- Share the same author-aware comment thread, replies, likes, and attachment actions between assignment comments and discussion threads.
- Route assignment and discussion comments through the verified Schoology comment endpoints.

### Messages and submissions
- Align the multi-line message editor with the Subject field while preserving line breaks in the sent message payload.
- Make text and file submission composers available from every assignment tab and return to Submissions after a successful submission.
- Add optional assignment-level comments to text and file submissions; post them separately from the revision so they remain attached to the overall assignment discussion.
- Prevent duplicate submission creation if posting the optional comment fails.

### Attachments and reading
- Reuse one attachments action list for posts, comments, and message details.
- Preserve the original attachment filename in save/export flows.
- Use native Liquid Glass View and Download buttons on supported OS versions, with a standard fallback.
- Keep iPhone/iPad course-material folder rows compact and limit folder descriptions to one line.
- Increase undersized imported post text while respecting Dynamic Type.

### Build
- Increment the iOS and macOS bundle build number to 49.

## [2026.10.0-port.48]

### Assignment submissions
- Replace separate file/resource submission actions with one Upload Submission flow.
- Stage multiple files and Schoology resources before submitting, then create one revision with a combined files payload.
- Show selected attachment names and per-file upload/completion feedback; choosing attachments no longer submits immediately.
- Match Android's native submission model and endpoint for file IDs and Schoology resource IDs.

### Course materials and resources
- Align folder icons vertically with folder names and indent descriptions with the folder text.
- Keep larger course-material row sizing exclusive to macOS; retain compact rows on iPhone and iPad.
- Open resource files through shared attachment preview/download actions and open resource links in the authenticated WebView.

### Posts, profile, and appearance
- Replace the duplicate signed-in account summary with the shared native person-profile page.
- Make the post comments action show Comment, the 1–2 count, or More Comments (N) without a separate View More Comments button.
- Correct only rich-text foreground colors that fail contrast in the active appearance, preserving readable author styling.

### Notifications
- Add a non-modal first-launch notification opt-in prompt on Home, with a clear explanation and Not Now option before Apple's permission request.

### Build
- Increment the iOS and macOS bundle build number to 48.

## [2026.10.0-port.47]

### Build fixes
- Fix the malformed notification-settings Swift key path that stopped the iOS Ad Hoc archive.
- Resolve Swift 6 notification delegate isolation and conditional Settings view compilation.
- Use Sendable string metadata overloads for APNs device registration across the Schoology API actor boundary.
- Keep the APNs entitlement on the iOS Ad Hoc target and exclude it from the Developer ID macOS target, which has no Push Notifications provisioning profile.

### Groups, courses, and school profiles
- Move permission-aware group creation actions into the app toolbar.
- Show the group’s school under its name and link school names from shared course/group infoboxes to the native school profile.
- Keep course, group, and school profile headers consistent; show profile artwork in the leading pane on three-pane layouts and retain it in the infobox on compact layouts.

### Rich text and attachments
- Preserve inline HTML text colors in comments while retaining rich text rendering for posts and message threads.
- Replace the attachment share action with the native save/export destination picker; use independent View and Download progress states and a macOS save panel with a saving-progress dialog.

### Calendar
- Use a side-by-side month and selected-day layout on wide windows.
- Match Android `EventCalls` month queries (`start_date`, `end_date`, 20-item offset pagination) and filter events to the selected month.
- Decode additional Schoology event field aliases so more event types appear in day details and calendar indicators.

### Build
- Increment the iOS and macOS bundle build number to 47.

## [2026.10.0-port.46]

### Push notifications
- Add native APNs registration and Schoology device-token registration through the existing `alert/device/{device_token}` API, matching the extracted iOS app and Android 2026.10.0 registrar.
- Add notification permission, enable/disable, and foreground sound settings for iPhone, iPad, and macOS.
- Add the APNs entitlement to both native targets. Device tokens remain memory-only and are not persisted locally.

### Rich text and embedded content
- Preserve Schoology HTML for posts, message threads, and comments.
- Render inline links, emphasis, and font styling as attributed text, and show embedded iframe/embed pages in an authenticated in-app web view.

### Messages and course materials
- Remove the nested NavigationStack from Messages so it uses the app's root navigation stack on iPhone.
- Increase course Materials folder and item hit areas to a settings-like minimum height across platforms.

### Build
- Increment iOS and macOS build number to 46.

## [2026.10.0-port.45]

### iOS navigation
- Use destination-based navigation links from the iPhone sidebar for Home sections, courses, and groups, while keeping the detail stack for secondary profile navigation.
- Keep sidebar navigation separate from the detail path so selecting a sidebar item opens the same native screen used by the working course dashboard links.
- Preserve selection-based navigation on macOS.

### Course, group, and school headers
- Make profile headers compact and align their avatar and typography with the Home welcome header.
- Remove the course code/identifier from the course header while retaining the school name when available.

### Build
- Increment bundle build number to 45.

## [2026.10.0-port.44]

### Course Pages
- Recognize Schoology Pages in course Materials, including nested folders.
- Load page content through the authenticated Sections Pages API.
- Render rich HTML in an in-app WebKit view with responsive media, relative asset URLs, and system light/dark colors.
- Decode page-specific IDs from course material records.

### iOS Ad Hoc build and notification preparation
- Fix the Swift concurrency compile error in the iOS background refresh handler by awaiting the MainActor-isolated sign-in state.
- Add the remote-notification background mode in preparation for APNs background delivery; actual delivery still requires the App ID capability, a matching profile, device-token registration, and a provider service.

### Build
- Increment bundle build number to 44.

## [2026.10.0-port.43]

### iOS navigation and updates
- Restore the detail-first compact navigation state so iPhone opens directly to Home.
- Prevent sidebar navigation path changes from feeding back into the root destination and replacing the active detail stack.
- Show the Tauri-matching installation notice after handing an iOS update manifest to the system installer.

### Messages
- Cache Inbox, Unread, and Sent independently after their first load.
- Load folders on demand, reuse cached results when switching, and show progress while a folder is loading.
- Preserve cached messages if a refresh fails.

### macOS presentation sizing
- Size attachment and likes sheets to their content, with a scrollable maximum height instead of a tall fixed minimum.

### Background notification refresh
- Schedule opportunistic iOS background refreshes for Schoology notifications without marking them read.
- Keep refresh work within iOS background execution limits; remote APNs delivery requires a separately configured provider service.

### Build
- Increment bundle build number to 43.

## [2026.10.0-port.42]

### Home create actions
- Discover discussion and event POST permissions for My Account, courses, and groups through Schoology multioptions.
- Expose only the creation actions and destinations explicitly permitted by Schoology.
- Add native discussion and event composers with publication, due date, grading, all-day, start/end date, RSVP, comments, file, and Schoology resource options.
- Submit Android/Tauri-compatible discussion and event payloads to the selected Schoology destination.

### Attachment viewing
- Preserve converted PDF URLs for post and message attachments when Schoology reports conversion success, allowing View to open the converted PDF while Download retains the original.

### macOS appearance
- Persist the selected appearance and synchronize SwiftUI's preferred scheme with AppKit's Aqua, Dark Aqua, or system appearance.

### Build
- Resolve conditional sidebar List modifier inference on iOS and macOS.
- Increment bundle build number to 42.

## [2026.10.0-port.41]

### Navigation and iOS build
- Fix the iOS archive failure caused by using the macOS-only `List(selection:)` initializer in the shared sidebar.
- Restore platform-appropriate sidebar behavior: iOS uses value-based navigation links into the detail stack, while macOS uses native list selection.
- Keep sidebar navigation routes separate from person-profile drill-ins, and persist destination navigation without feeding detail-stack changes back into the sidebar selection.

### Build
- Increment the iOS and macOS bundle build number to 41.

## [2026.10.0-port.40]

### Navigation
- Rebuild the sidebar around one shared `NavigationSplitView` selection binding on iOS, iPadOS, and macOS.
- Make course, group, and destination links update the split-view selection directly instead of targeting a separate detail-stack route.
- Keep the detail `NavigationStack` for deeper destinations such as person profiles, avoiding competing navigation ownership between the sidebar and detail stack.

### Build
- Increment the iOS and macOS bundle build number to 40.

## [2026.10.0-port.39]

### Navigation
- Repair iOS sidebar navigation by removing the detail-stack identity reset and the feedback loop that changed the selected sidebar root while SwiftUI was processing a sidebar link.
- Keep value-based sidebar links routed into the detail NavigationStack, while macOS retains native List selection.

### Teacher grading
- Open a student's full submission review from the teacher Submissions list.
- Load that student's actual submission revisions, status, text, and file attachments using the official per-user submissions endpoint.
- Show the student's profile photo and support editing the grade, overall comment, and student-visible comment setting in the same review.
- Use converted PDFs for revision attachments when Schoology provides converted download URLs.

### Build
- Increment the iOS and macOS build number to 39.

## [2026.10.0-port.38]

### Person profiles
- Redesign person profiles to match Schoology's Updates, Info, and Badges sections, with adaptive compact and wide layouts.
- Load profile updates through the shared post cards so likes, comments, and recent-comment previews work consistently.
- Show the person's photo, school, preferred name, role, email, username, and available name details.

### Posts and comments
- Show the two most recent comments beneath shared post cards, using the same nested comment rows and a View more comments action.
- Remove the redundant New comment toolbar action from the comments sheet.

### Messages and course materials
- Use the signed-in user's actual profile photo for messages authored by You.
- Give the message composer a padded, true multiline editor that inserts line breaks with Return.
- Display course-material folder descriptions beneath folder names.
- Route course-material files through the shared View or Download actions and use Schoology's converted PDF for viewing when supplied.

### macOS
- Add macOS Sonoma 14 as the minimum supported macOS version.
- Use the legacy assignment tabs and AuthenticationServices callback initializer on macOS 14.0–14.3, with the modern APIs on newer releases.
- Retain native segmented/material fallbacks on older systems and Liquid Glass on supported releases.
- Apply the same adaptive navigation picker style to Settings' Theme control.
- Fix the sidebar view-builder compile error that blocked the previous iOS and macOS Actions archives.

### Build
- Increment the iOS and macOS bundle build number to 38.

## [2026.10.0-port.37]

### Shared profile presentation
- Add one adaptive Schoology profile infobox for courses, groups, and schools.
- Place profile identity above portrait section pickers and above active content in wide layouts.
- Keep wide navigation sidebars focused on navigation instead of repeating profile hero content.

### School resources
- Reuse the recursive shared resources browser for school resources, including nested folders and collection-backed folder loading.
- Keep resource loading, empty, error, and refresh states consistent with standalone and group resources.

### Permissions and creation
- Read course update and document POST permissions through Schoology multioptions before exposing course actions.
- Send multioptions requests as JSON, matching the official desktop port's Schoology API request format.
- Add permission-aware course actions for posting updates and opening the official Schoology resource creator.
- Add a homepage update composer only for courses and groups where Schoology confirms update POST access.
- Share the update composer across homepage and course contexts, including file and Schoology resource attachments.

### Messages
- Add native file and Schoology resource attachments to the new-message composer.
- Upload files through Schoology FileService and submit the Android-compatible `file-attachment` and `attachments` payload fields.

### Notifications
- Route assignment notification links using the notification's owning realm ID, matching Android's NotificationIntent behavior instead of requiring the notification realm string to be `sections`.
- Open related user, group, course, and school items in native profile pages when possible.

### Build
- Increment the iOS and macOS bundle build number to 37.


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
