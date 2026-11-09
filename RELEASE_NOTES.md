# Release notes

## [2026.10.0-port.103]

### Google OAuth and SwiftUI archive fixes
- Add the missing Google refresh-token Keychain read, write, and delete operations used by the native Cloud setup.
- Use the modern authentication-session callback API where supported and retain the compatible macOS 14.0 initializer fallback.
- Register Google's reversed-client-ID callback URL scheme for the iOS, Catalyst, and native macOS targets.
- Replace the unsupported accessibility live-region modifier with a supported status label and correct the Google project status string interpolation.

### Apple-silicon Mac iPad-app testing
- Keep the native macOS target and its signing/build configuration unchanged.
- Preserve the dedicated Ad Hoc workflow that exports the iPad app for a registered Apple-silicon Mac; no iOS-to-Mac opt-out flag was present in the iOS target's build settings or generated Info.plist configuration.

### Build
- Increment the iOS and macOS bundle build number to 103.

## [2026.10.0-port.102]

### Native Google Cloud and Gemini setup
- Add Google OAuth authorization for iOS, iPadOS, and macOS using the registered iOS OAuth client, PKCE, and Apple's system authentication session.
- Store Google refresh tokens in Keychain; no OAuth client secret is embedded.
- Search active Google Cloud projects, enable the required services, create or reuse the dedicated ClassWire Gemini service account, and create or reuse a Gemini-only authorization key. Project discovery errors remain visible without losing the Google sign-in.
- Store the generated Gemini API key in Keychain and retain manual key entry as a fallback.

### SwiftUI build fixes
- Replace the unsupported accessibility live-region modifier with a supported accessible status label.
- Split the AI settings form into smaller computed views to avoid Swift compiler type-check timeouts.

### Build
- Increment the iOS and macOS bundle build number to 102.

## [2026.10.0-port.101]

### iPad course, group, and school profiles
- Remove the redundant large navigation-bar title for course, group, and school profiles when the iPad has a regular-width layout; keep the full title in the profile infobox.
- Preserve the existing navigation title on iPhone and macOS, and allow it to return when an iPad window becomes compact.

### ClassWire AI build fixes
- Break the AI conversation timeline into smaller SwiftUI view expressions so Xcode can type-check the iOS and macOS targets reliably.
- Apply the iOS keyboard capitalization modifier only on iOS; keep shared AI settings compatible with macOS.

### Build
- Increment the iOS and macOS bundle build number to 101.

## [2026.10.0-port.100]

### ClassWire AI for SwiftUI
- Add a native ClassWire AI assistant for iPhone, iPad, and Mac with provider selection for Gemini, OpenAI, Anthropic, and Ollama.
- Store provider API keys in Apple Keychain and keep conversation history locally on the device.
- Port tool-assisted Schoology lookups for courses, groups, upcoming events, assignments, grades, materials, updates, messages, and assignment submissions, with contextual navigation.
- Require explicit in-app confirmation before proposed assignment submissions, messages, course updates, or teacher grade changes are executed.
- Add adaptive conversation history, a native chat composer, provider settings, and Markdown responses.
- Preserve platform-native navigation and support Dynamic Type, VoiceOver, dark mode, and Reduce Motion.
- Native Google Cloud OAuth project/key provisioning is not included in this first SwiftUI port; Gemini API keys can be entered and stored securely in Keychain.

### Build
- Increment the iOS and macOS bundle build number to 100.


## [2026.10.0-port.99]

### Demo mode layout
- Place the iPhone demo-mode controls in the app's actual vertical layout, before the NavigationSplitView, instead of attaching them as a top safe-area decoration.
- Move the iOS update notice into the same outer layout so neither banner is layered over the navigation bar or destination content.
- Preserve the macOS navigation and update-banner presentation.

### Build
- Increment the iOS and macOS bundle build number to 99.


## [2026.10.0-port.98]

### Demo mode layout
- Move the iOS demo-mode controls from the bottom edge to a top safe-area bar above the navigation and title bar, preserving visibility across destinations while restoring the full bottom scrolling area.
- Use `safeAreaBar(edge: .top)` on iOS 26 and later and a top `safeAreaInset` fallback on iOS 18–25.
- Remove the bottom-edge background extension and place the subtle separator at the bottom of the top bar.

### Build
- Increment the iOS and macOS bundle build number to 98.


## [2026.10.0-port.97]

### Demo mode navigation
- Attach the iOS demo-mode bar to the outer app-content shell instead of the NavigationSplitView detail hierarchy, so it remains visible across compact iPhone sidebar navigation and pushed destinations.
- Use SwiftUI's safe-area bar API on iOS 26 and later, with the safeAreaInset fallback for iOS 18–25 so the bar reserves space instead of covering page content.

### Build
- Increment the iOS and macOS bundle build number to 97.


## [2026.10.0-port.96]

### Build fix
- Fix the text-submission formatting bar's Insert Link action by presenting the existing shared link sheet directly.
- Remove stale references to link-entry state that belongs to the shared sheet, fixing the Swift compile errors that blocked both iOS and macOS archives.

### Build
- Increment the iOS and macOS bundle build number to 96.


## [2026.10.0-port.95]

### Assignment and discussion due dates
- Parse Schoology legacy local date-time values, ISO-8601 timestamps, and Unix timestamps consistently.
- Display assignment and discussion due dates as localized absolute date-and-time labels instead of raw API strings.
- Apply the same date presentation to gradebook assignment rows while preserving role labels and non-due metadata.

### Build
- Increment the iOS and macOS bundle build number to 95.


## [2026.10.0-port.94]

### Demo navigation and Settings
- Move the iOS demo-mode banner to the outer NavigationSplitView so it remains attached when compact iPhone navigation collapses and pushes sidebar destinations.
- Remove the extra outer padding and desktop-width constraint from the iPhone Settings Form while preserving the macOS window layout.

### Rich-text composers
- Add the shared bold, italic, underline, and link toolbar to discussion, event, update, and new/reply message composers on iOS 26 and macOS 26.
- Serialize formatted content as HTML for Schoology discussion bodies, event descriptions, updates, and messages; retain plain text in demo mode.
- Reuse the validated link insertion sheet across text submissions and the additional composers.
- Keep the existing iOS 18 and macOS 14 deployment targets; older systems retain their existing plain-text editor fallback.

### Build
- Increment the iOS and macOS bundle build number to 94.


## [2026.10.0-port.93]

### Demo banner navigation persistence
- Attach the iOS demo-mode bar to the NavigationStack container itself, rather than only its root destination.
- Keep the demo notice, role selector, and Exit Demo action visible while navigating to destinations pushed from the sidebar, including course and group profiles.
- Reserve the bar's space across the full navigation stack so destination content and scrolling remain unobstructed.

### Build
- Increment the iOS and macOS bundle build number to 93.

## [2026.10.0-port.92]

### Comments keyboard behavior
- Remove the extra keyboard Done/checkmark control from the shared comments composer.
- Dismiss the software keyboard when tapping outside the comment field in the thread, and allow interactive keyboard dismissal while scrolling.
- Keep the Post action available beside the comment field.

### Demo mode banner
- Attach the signed-in demo-mode bar directly to the selected root content rather than the NavigationStack container, so it remains visible in the compact iPhone navigation layout while reserving space for scrollable content.
- Attach the standalone demo preview banner to its active detail content and keep its label legible at compact widths.

### Build
- Increment the iOS and macOS bundle build number to 92.

## [2026.10.0-port.91]

### Date and time labels
- Use the same Schoology-style timestamp presentation for activity posts and message conversation details as comments: relative labels for the most recent 24 hours, then a localized absolute date and time for older entries.
- Keep the Messages inbox list's existing compact relative timestamp treatment.

### Comments composer
- Move the iOS keyboard Done checkmark above the comment field, aligned to the trailing edge, so it no longer replaces or overlaps the Post button.
- Keep Post visible beside the comment field while editing.

### School discussions
- Open the School Discussions fallback inside ClassWire's shared authenticated WebKit view, using the existing Schoology web-session cookie bootstrap.
- Respect the selected Schoology region when choosing the school web host.

### Demo mode layout
- Attach demo banners to the active navigation content stack so SwiftUI reserves the banner space in the scrolling content area on iPhone.
- Keep the demo controls and sample-data notice accessible without covering the last rows of content.

### Build
- Increment the iOS and macOS bundle build number to 91.

## [2026.10.0-port.90]

### Composer keyboard controls
- Replace each iOS composer’s trailing action with a prominent blue checkmark while a text field is focused; tapping it dismisses the keyboard without submitting or discarding the draft.
- Apply the same keyboard-dismissal affordance to update, event/discussion, message, text/file assignment submission, and shared comment composers.
- Keep each composer’s normal Post, Send, Create, or Submit action available after editing ends; preserve the existing macOS toolbar actions.

### Event and discussion information
- Align event and discussion information cards with the assignment detail layout: title and date first, attachments next, and description afterward.
- Keep event attachments inside the rounded information card, matching assignments and discussions.

### Build
- Increment the iOS and macOS bundle build number to 90.

## [2026.10.0-port.89]

### Deep links
- Handle the Classic Chrome-link handoff format, `schoology://link?url=...`, by validating and opening its HTTP or HTTPS destination with the system URL handler.
- Leave `schoology://external_login_callback` to AuthenticationServices so OAuth callbacks are not mistaken for ordinary links.
- Ignore malformed, unsupported, or non-web custom destinations rather than opening arbitrary URL schemes.

### Assignment information
- Move the View Attachments disclosure below the assignment title, due date, and points, and above the description.

### Build
- Increment the iOS and macOS bundle build number to 89.


## [2026.10.0-port.88]

### Classic updates and text submissions
- Select only ClassWire-named assets when checking for a new Classic macOS or iOS release, while continuing to publish Schoology-named aliases.
- Move the rich-text formatting bar above the software keyboard while editing on iPhone; keep it below the editor when the keyboard is closed.

### Build
- Increment the iOS and macOS bundle build number to 88.


## [2026.10.0-port.87]

### App updates and releases
- Have in-app updates select only the new ClassWire-named macOS installer and iOS manifest.
- Continue publishing the Schoology-named release aliases for existing users and older install flows.

### Build
- Increment the iOS and macOS bundle build number to 87.


## [2026.10.0-port.86]

### App updates and releases
- Keep publishing both ClassWire and Schoology named macOS and iOS release assets.
- Validate that all Schoology-named iOS installer, manifest, and QR aliases are present before publishing.
- Let in-app updates use the ClassWire asset names first and fall back to the matching Schoology-named macOS installer or iOS manifest.

### Build
- Increment the iOS and macOS bundle build number to 86.


## [2026.10.0-port.85]

### Text submissions
- Keep rich-text formatting controls visible below the editor, including when the keyboard is dismissed, and present them with Liquid Glass.
- Insert hyperlinks using separate text and link fields.

### Messages
- Put Refresh beside Compose in the Messages app bar.
- Prefer original message attachment filename metadata so attachment rows, preview actions, and saved files retain their names.

### Build
- Increment the iOS and macOS bundle build number to 85.


## [2026.10.0-port.84]

### Assignment submissions
- Make the Download action request only the original uploaded attachment; reserve converted files for View.
- Allow legitimate HTML attachments to download while rejecting sign-in and expired-session pages returned as HTML.
- Add native bold, italic, underline, and link formatting to the text-submission editor on iOS 26 and macOS 26, with a plain SwiftUI text editor fallback on earlier supported versions.

### Build
- Increment the iOS and macOS bundle build number to 84.

## [2026.10.0-port.83]

### Assignment submission attachments
- Use one shared revision-attachment decoder for student and teacher submission histories.
- Preserve the original Schoology file URL exclusively for Download and keep the converted preview URL separate for View.
- Recognize the same original and converted URL field variants as the desktop attachment flow, preventing assignment submissions from previewing the uploaded original when Schoology provides a converted copy.
- Do not silently treat a converted-only response as the original downloadable file.

### Build
- Increment the iOS and macOS bundle build number to 83.

## [2026.10.0-port.82]

### iPhone and iPad navigation
- Restore native SwiftUI NavigationLink navigation for iPhone and iPad sidebar destinations, courses, and groups.
- Let NavigationSplitView present those links in the next column on wide layouts and push them onto the navigation stack when collapsed on iPhone.
- Keep selection-driven sidebar synchronization on macOS, where the native selectable List behavior is appropriate.
- Avoid manually mutating split-view selection from plain sidebar buttons on compact iPhone layouts.

### Build
- Increment the iOS and macOS bundle build number to 82.


## [2026.10.0-port.81]

### Adaptive navigation
- Use a selection-driven NavigationSplitView sidebar on iPad and macOS so choosing a course or group replaces the selected detail.
- Replace nested profile List(selection:) tab pickers with explicit, accessible tab buttons so the course and group middle panes reliably follow the selected section.
- Keep sidebar route changes synchronized with the app destination on every supported platform.

### Offline demo workflows
- Add a student/teacher preview switch to demo mode and make teacher grade edits persist locally, including score, overall comment, and student visibility.
- Allow a discussion created in a demo group to include a locally stored file attachment that appears in its discussion detail.
- Add local photo importing to demo albums and retain imported photos for the active demo session.
- Bundle a genuine one-page PDF study guide so document preview and download workflows work fully offline.
- Keep demo uploads local; no attachment, photo, grade, or discussion is sent to Schoology.

### TestFlight
- Compile TestFlight builds with the CLASSWIRE_TESTFLIGHT condition and a TestFlight distribution marker.
- Hide the Software Update section in TestFlight Settings and skip startup self-update checks in TestFlight builds.

### Build
- Increment the iOS and macOS bundle build number to 81.


## [2026.10.0-port.79]

### Demo mode
- Replace the separate demo-only app shell with the normal ClassWire navigation split view and existing destination screens.
- Move the iOS demo status and exit control to a safe-area-aware bottom bar; use the macOS toolbar instead of placing critical controls at the bottom of a resizable window.
- Seed normal app screens with fictional courses, groups, activity, upcoming events, messages, notifications, grades, resources, and people.
- Route supported demo screen loads to local sample models without making Schoology API requests or changing saved Keychain credentials.
- Keep demo exit available from the bottom bar and the standard sidebar.

### Build
- Increment the iOS and macOS bundle build number to 79.


## [2026.10.0-port.78]

### Schoology terminology
- Restore the accurate “Attach Schoology Resource” label in message, update, and home-create composers.

### App Store encryption compliance
- Declare that the app uses no non-exempt encryption in the generated iOS, Catalyst, and macOS Info.plists.
- Document the app's OS-provided HTTPS/TLS transport, CryptoKit HMAC request authentication, SHA-256 integrity checks, and Keychain usage.
- Validate the TestFlight IPA's export-compliance Info.plist value before attempting App Store Connect upload.

### Build
- Increment the iOS and macOS bundle build number to 78.


## [2026.10.0-port.77]

### Messages
- Move Reply into the conversation detail's own navigation toolbar so it remains visible on compact iPhone navigation and in the iPad split-pane detail.
- Keep Reply disabled until the thread has loaded a valid recipient, and refresh that context after pull-to-refresh.

### iOS/iPadOS distribution
- Declare all four supported orientations for iPad multitasking in the generated Info.plist for the iOS and Catalyst targets.
- Keep iPhone orientation support limited to portrait and the two landscape orientations.

### Build
- Increment the iOS and macOS bundle build number to 77.


## [2026.10.0-port.76]

### Apple-silicon Mac testing
- Keep ordinary iOS/iPadOS TestFlight uploads focused on the iPad app; Apple-silicon Mac testing uses the TestFlight tester-group compatibility setting.
- Add a separate optional Ad Hoc workflow to export the iPad app for a registered Apple-silicon Mac without TestFlight.
- Make experimental Mac Catalyst TestFlight upload opt-in and independent from iOS TestFlight.
- Fix the Catalyst preview to build the dedicated Catalyst target instead of overriding the iOS target's platform support.

### Brand mark
- Nudge the ClassWire C glyph a tiny additional amount to the left in generated app icons and the SwiftUI sign-in mark.

### Build
- Increment the app build number to 76.


## [2026.10.0-port.75]

### App Review and demo
- Expand the local demo to cover notifications, assignments, people, requests, settings, detailed assignment workflows, post discussions, and file previews using local-only sample interactions.
- Keep LTI assignments distinct from normal assignments and omit submission creation controls for external-tool activities.
- Preserve any previously saved Schoology credentials when entering and exiting demo mode.

### Privacy
- Replace the inaccurate privacy policy with a description of the actual Schoology, Apple APNs, GitHub, WebKit, and external-tool data flows and local storage behavior.
- Add an in-app Privacy Policy link in Settings.

### TestFlight and Mac Catalyst
- Add a separate experimental Mac Catalyst target that reuses the iPad app source without modifying the native macOS target.
- Extend the TestFlight-only workflow to build, sign, and upload the Catalyst platform build to App Store Connect alongside the iOS build.

### Brand mark
- Nudge the C glyph slightly left to correct its visual balance.

### Build
- Increment the app build number to 75.


## [2026.10.0-port.74]

### App Review demo mode
- Add a local interactive demo entry for tester@classwire.app with a confirmation dialog before entering.
- Add representative sample screens for Home, Courses, Upcoming, Grades, Calendar, Messages, Groups, Resources, and Profile.
- Keep demo interactions local and clearly disclose that no Schoology records are changed.
- Document Apple's prior-approval requirement and the remaining gap between this initial interactive demo and a fully featured production-equivalent demo.

### Profile avatars
- Standardize missing profile-photo fallbacks as person glyphs in rounded-square containers across profile, comments, likes, directory, messages, and submissions.

### Build
- Increment the app build number to 74.


## [2026.10.0-port.73]

### Icon refinement
- Reduce the ClassWire C glyph to 70% and shift its artwork right to visually center it within the circular mark, in both generated app icons and the SwiftUI sign-in brand mark.

### Assignments
- Hide the Create Submission toolbar action for LTI plugin assignments; retain it for normal assignments that support submissions.

### Mac Catalyst preview
- Add an optional manual GitHub Actions workflow to build an unsigned Mac Catalyst preview from the existing iPad app target.
- Keep the existing native macOS target and distribution workflow unchanged; the preview does not modify project settings or upload to the Mac App Store.

### Build
- Increment the app build number to 73.


## [2026.10.0-port.72]

### ClassWire identity
- Slightly reduce the C glyph from 78% to 75% of its base vector size in generated iOS/macOS app icons and the SwiftUI sign-in brand mark.

### App Store preparation
- Set the planned App Store Connect SKU to CLASSWIRE-IOS-001 and document the iOS + macOS platform record setup for a future universal purchase.
- Clarify that the existing native macOS Developer ID app is unchanged and is not the Mac Catalyst App Store build.
- Replace the inaccurate App Store description draft with a plain-language summary of implemented ClassWire functionality.
- Add a sample Schoology review-account checklist without embedding or fabricating credentials.

### Build
- Increment the iOS and macOS bundle build number to 72.


## [2026.10.0-port.71]

### ClassWire identity
- Reduce the C glyph to 78% of its previous size inside the circular mark in generated iOS/macOS app icons, the sign-in brand lockup, and the account sign-in button.

### TestFlight
- Add a manual workflow checkbox to build and upload only the iOS TestFlight package, skipping macOS and Ad Hoc jobs.
- Validate the App Store Connect provisioning profile and exported IPA before upload.
- Document App Store Connect setup, signing prerequisites, reviewer information, and the real demo-account requirement.

### Build
- Increment the iOS and macOS bundle build number to 71.


# Release notes

## [2026.10.0-port.70]

### ClassWire rebrand
- Rebrand the app display name, navigation and settings labels, sign-in wordmark, accessibility label, update messaging, and generated iOS/macOS app icons as ClassWire.
- Replace the original S glyph with a matching custom C mark in the sign-in logo and generated app icons.
- Rename versioned release assets and the installed macOS app bundle to ClassWire while retaining the existing bundle identifier and Schoology sign-in callback for upgrade compatibility.
- Publish temporary legacy Schoology-named copies of the new packages so existing pre-rebrand update checkers can discover the transition release.

### Messaging
- Add a native Reply action to the Messages toolbar, including the macOS and iPad split-pane detail state.
- Prefill the reply recipient and original subject from the latest incoming message in the conversation, and send through the same message-thread endpoint and JSON payload used by Tauri.
- Preserve file and resource attachments when replying.

### OAuth and comments
- Match Android and Tauri OAuth normalization by excluding form-body fields from the signature parameter set.
- Use Tauri's 128-bit random nonce plus a monotonic per-process sequence, and refresh the server-time offset before the one-time replay retry.
- Submit activity-post comments as JSON with a numeric parent ID.

### Build
- Increment the iOS and macOS bundle build number to 70.


## [2026.10.0-port.69]

### Post comments and OAuth reliability
- Send shared activity-post comments and replies as JSON with a numeric `parent_id`, matching the Tauri implementation.
- Retry once with a newly generated OAuth nonce and signature only when Schoology explicitly rejects a request for a duplicate timestamp/nonce replay.
- Use the full unsigned 64-bit hexadecimal nonce range, matching the Tauri signer.

### Build
- Increment the iOS and macOS bundle build number to 69.


## [2026.10.0-port.68]

### macOS three-pane layouts
- Replace nested three-column NavigationSplitViews in course, group, and school profiles with a bounded sidebar, flexible full-width content pane, and bounded Upcoming pane.
- Keep the middle pane flexible as the window grows instead of allowing nested split-view balancing to compress its content.

### Profile images
- Use rounded-square clipping for profile avatars in the homepage welcome area, activity posts, messages, comments, likes, people directory, and student submission header.

### Build
- Increment the iOS and macOS bundle build number to 68.


## [2026.10.0-port.67]

### Attachment downloads and media playback
- Establish the authenticated Schoology web session before downloading attachments, forwarding its session cookies only to matching Schoology hosts during redirects.
- Avoid forwarding Schoology account cookies to unrelated redirected file hosts.
- Surface attachment HTTP failures and HTML sign-in responses with useful details instead of collapsing them into a generic invalid-response error.
- Increase the attachment download ceiling to accommodate larger media files.

### Documentation
- Rewrite the README to reflect the implemented native SwiftUI features, platform targets, reference sources, accessibility approach, and current CI release process.

### Build
- Increment the iOS and macOS bundle build number to 67.


## [2026.10.0-port.66]

### Messages and profiles
- Remove the duplicate profile refresh action so the remaining app-bar control displays the loading spinner.
- Add a spinner-aware refresh action to the Messages app bar for the selected folder.

### Attachments and assignment details
- Preserve original video and audio files when viewing or downloading attachments instead of routing them through PDF conversion.
- Add a native AVKit media viewer for common video and audio formats, including MP4, M4A, and MP3.
- Move the assignment attachment disclosure to the top of the Info content, before the assignment description.

### Build
- Increment the iOS and macOS bundle build number to 66.

## [2026.10.0-port.65]

### Resources and resource apps
- Correctly recognize root-level parent folders from Schoology document metadata so folders expand recursively inline.
- Keep native SwiftUI folder symbols while applying the folder colors returned by Schoology.
- Display resource-app logos from the Schoology app-logo field.
- Reorganize the resource attachment picker into the same My Resources, Shared, Groups, and Resource Apps categories as the standalone Resources page.
- Support importing files and links from inside resource apps using the Android app's `/content_app/import?mobile=1` flow, authenticated with the current Schoology session.

### Navigation and refresh
- Use native SwiftUI sidebar-style Lists with selection for wide course, group, and school profile layouts.
- Show the school profile reload spinner while its selected tab is refreshing.
- Remove the duplicate notifications toolbar reload action and keep the spinner-aware refresh control.

### Build
- Increment the iOS and macOS bundle build number to 65.

## [2026.10.0-port.64]

### Refresh controls
- Show an in-toolbar progress indicator while homepage, course, and group refresh requests are running.
- Keep course and group refresh actions directly accessible in the toolbar beside their create actions.

### Attachments
- Open link attachments directly in the system browser when selected.
- Give the shared post attachment list a consistent rounded, contrasting background wherever it is reused.
- Replace the assignment, discussion, and event attachment blocks with expandable inline “View Attachments (N)” sections.

### Build
- Fix the invalid SwiftUI frame modifier that caused both iOS and macOS archive jobs to fail.
- Increment the iOS and macOS bundle build number to 64.

## [2026.10.0-port.63]

### Assignment submissions
- Match the Upload Submission toolbar action's Submit label and paper-plane icon to the Create Text Submission dialog.

### Course Materials and Resources
- Restore comfortable vertical padding around folder titles and multiline descriptions.
- Give link materials a link icon and open their destinations through the system browser.

### Calendar and assignment layouts
- Match the port.28 assignment information/submissions split at 17:7.
- Match the port.28 calendar month/events split at 40:60 on wide screens.
- Keep the calendar at the top on narrow layouts and anchor selected-day content to the top; make the wide events pane independently scrollable.

### Shared comments
- Preserve rich text and Dynamic Type sizing in comment bodies.
- Keep the Liquid Glass action bar content-sized instead of stretching it across the comment card.
- Hydrate missing author names and avatars for assignment and discussion comments using the same user-profile lookup as post comments.
- Correct deleted-comment status parsing so ordinary string statuses do not hide Reply actions.

### School profiles
- Load school details first, then fetch updates and upcoming content separately.
- Load resources and discussions only when their tabs are opened, retain loaded tab data when switching, and support per-tab refresh/error/loading states.

### Notifications
- Resolve related document items through their owning Schoology realm and show the native attachment view/download actions or open link destinations in the browser.
- Handle file, link, and external-tool document attachment URLs instead of routing document IDs to an invalid webview URL.

### Build
- Increment the iOS and macOS bundle build number to 63.

## [2026.10.0-port.62]

### Discussion routing
- Normalize discussion identifiers from group and school discussion lists, preferring the actual discussion ID over generic template or row IDs.
- Use the same native discussion detail page for group discussions, course materials, and other supported discussion entry points.

### Shared comments
- Route post, assignment, discussion, and event comment threads through one shared comments view with identical comment cards, reply composer, ordering, refresh behavior, and profile/likes navigation.
- Give comment action controls the same adaptive Liquid Glass surface used by post actions, with a material fallback on older systems.

### Rich text and sizing
- Apply Dynamic Type-scaled minimum sizing to assignment descriptions and teacher comments, discussion descriptions, and event descriptions while retaining inline rich text and links.

### Course Materials and Resources
- Remove explicit macOS and iOS/iPadOS row minimum-height overrides and the iOS-only regular control-size override; allow native SwiftUI row sizing on both platforms.

### Build
- Fix the CGFloat string conversion that caused both iOS and macOS archive jobs to fail.
- Increment the iOS and macOS bundle build number to 62.

## [2026.10.0-port.61]

### Course Materials and Resources
- Restore the familiar inline DisclosureGroup folder layout from port.48, with folder descriptions aligned beneath their titles and nested items using native disclosure indentation.
- Keep compact, platform-appropriate row sizing instead of reintroducing the old oversized macOS control-size override.
- Apply the same inline folder and item hierarchy to the Resources page.

### Upcoming and Calendar
- Decode Schoology event realm and realm-specific IDs for sections, groups, schools, and users so calendar and global Upcoming items open their actual event destination.
- Route group discussions and section external tools using their Android-compatible identifiers.
- Resolve external-tool launch URLs from the section document endpoint before opening the authenticated embedded web view.

### Scrolling Performance
- Add a bounded, per-account in-memory cache for authenticated post images to avoid re-downloading them while scrolling back through Recent Activity.
- Cache parsed rich HTML attributed text by content, appearance, and minimum font size so row updates do not repeatedly re-import the same HTML.

### Build and Release
- Fix the release-note heading for port.60 and use the workflow's expected versioned heading for this release.
- Increment the iOS and macOS bundle build number to 61.

## [2026.10.0-port.60]

### Attachments
- Open Schoology link attachments directly in the system browser instead of treating them as downloadable files.
- Preserve link attachments from assignment info, activity, messages, comments, events, and submission revisions.

### macOS app icon
- Add rounded-corner legacy Mac icon renditions so older macOS releases display a finished rounded icon while iOS artwork remains unmasked.

### macOS updates
- Resolve the installed app when macOS launches a quarantined or disk-image copy.
- Stage replacement bundles beside the installed app, verify the copied signature, and roll back if replacement fails.
- Request administrator authorization when the Applications folder is not writable, then relaunch the updated app.
- Write persistent diagnostics to ~/Library/Logs/Schoology/update-*.log and reopen the previous app when an update cannot complete.

### Build
- Increment the iOS and macOS bundle build number to 60.

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
