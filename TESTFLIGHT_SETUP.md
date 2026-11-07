# TestFlight and App Store Connect setup for ClassWire

The iOS/iPadOS TestFlight workflow is separate from the existing registered-device Ad Hoc installer and Developer ID macOS release. The existing native macOS app remains a separate Developer ID distribution target.

## 1. App Store Connect app record

Create one ClassWire app record with these values:

- **Platforms:** select both **iOS** and **macOS** if you want to reserve the record for a future universal purchase.
- **Name:** ClassWire
- **Primary language:** English (U.S.)
- **Bundle ID:** `com.schoologytauri.app`
- **SKU:** `CLASSWIRE-IOS-001`

The SKU is an internal identifier, not shown to customers. It must be unique in your App Store Connect account and cannot be changed after the record is created. If this exact SKU is already in use, choose a different unique SKU before creating the record.

Both platforms in one record share the same Apple app identifier, SKU, and bundle ID. Apple requires a separate Xcode target and a separately uploaded build for each platform. Selecting macOS in App Store Connect does **not** automatically turn the existing native macOS app into a Mac Catalyst app.

### Mac Catalyst status

The current project has two separate targets: the iOS/iPadOS app and the existing native macOS app. The iOS target currently has Mac Catalyst disabled. The existing macOS target is a native macOS app distributed with Developer ID and notarization; it is not a Mac Catalyst build and must remain unchanged.

A Mac Catalyst App Store version needs its own platform build/archive and Mac App Store Connect signing workflow, using the same bundle ID for a universal purchase. However, you can preview the current iPad UI as Catalyst without changing the native macOS target or maintaining a second source implementation: use the manual **Build a temporary Mac Catalyst preview** workflow input. It temporarily overrides SUPPORTS_MACCATALYST for the existing iOS target, builds an unsigned .app, and uploads it as a GitHub artifact. This preview is for visual inspection only; it is not a signed Mac App Store build. Do not upload the existing Developer ID DMG as the macOS App Store build.

Apple does not provide TestFlight distribution for macOS builds. The iOS/iPadOS build can use TestFlight; a Catalyst Mac build needs to be tested and distributed through the Mac App Store workflow or another supported Mac distribution/testing route.

Adding macOS now lets you explore the platform setup, but be aware: after App Review approves at least two platform versions, the record becomes a universal purchase and Apple says you can no longer remove an individual platform from it. Before any macOS build is uploaded, Apple allows an eligible platform entry to be removed while the app record is still editable.

## 2. App Store description

The repository's `description.md` is a draft source for the App Store description. Copy its plain-text contents into the iOS platform's **Description** field in App Store Connect. Apple permits up to 4,000 characters; Markdown formatting is not rendered as formatting, so paste plain text rather than Markdown syntax. Keep the macOS description separately tailored if you later publish the Catalyst platform.

## 3. Apple signing assets

The iOS TestFlight workflow uses App Store Connect distribution signing, not Ad Hoc signing:

- An active **Apple Distribution** certificate exported as a password-protected `.p12`.
- An active **App Store Connect** provisioning profile for the explicit App ID `com.schoologytauri.app`, associated with that distribution certificate.
- The existing App Store Connect API key with permission to access signing assets and upload builds.

The workflow downloads the App Store Connect profile at run time using the API key and checks that its App ID/team match, `get-task-allow` is false, and it does not contain a device list.

## 4. GitHub Actions secrets and variables

Verify these under **Settings → Secrets and variables → Actions**:

| Name | Type | Purpose |
| --- | --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | Secret | Base64-encoded Apple Distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | Secret | Password for the certificate |
| `APPSTORE_API_PRIVATE_KEY` | Secret | Raw App Store Connect `.p8` private-key contents |
| `APPSTORE_API_KEY_ID` | Variable or secret | Key ID for the `.p8` key |
| `APPSTORE_ISSUER_ID` | Variable or secret | App Store Connect issuer UUID |
| `APPLE_TEAM_ID` | Variable or secret | 10-character Apple Developer Team ID |

The App Store Connect API key should have a role that permits uploading builds (App Manager or Admin is the straightforward choice) and access to the ClassWire app. The workflow does not need your Apple Account password or an app-specific password for this upload path.

Do not add credentials to workflow YAML, source code, release notes, or this document.

## 5. Run only the TestFlight build

1. Open the repository's **Actions** tab.
2. Select **Build and release ClassWire SwiftUI**.
3. Choose **Run workflow** on the `main` branch.
4. Check **Build and upload only the iOS TestFlight package (skips macOS and Ad Hoc)**.
5. Leave **Build and publish only the iOS Ad Hoc package** unchecked, then run the workflow.

When TestFlight is checked, the macOS, Ad Hoc IPA, and GitHub Release jobs are skipped. The dedicated TestFlight job archives, exports, validates, and uploads the App Store Connect IPA. Apple processing is asynchronous; a successful upload does not mean the build is already visible or approved.

## 6. Reviewer sign-in and Apple's beta review

Use the checklist in [APP_REVIEW_ACCOUNT.md](APP_REVIEW_ACCOUNT.md) to arrange a dedicated, authorized Schoology test account with representative, non-sensitive sample data. ClassWire cannot create a Schoology account on behalf of a school, and a fake login or placeholder account would not provide reviewers with access to real functionality.

Before requesting external TestFlight review:

1. Confirm the dedicated Schoology test account can sign in using **Sign in with my account** and remains active for the review period.
2. If the account is controlled by a school or district, obtain authorization from that administrator.
3. In App Store Connect → ClassWire → TestFlight → Test Information, enter the beta description and a monitored feedback email.
4. In the build's **TestFlight App Review Information**, indicate whether sign-in is required and provide the working demo username/password and any school/domain selection instructions. Include required MFA or access steps in review notes.
5. Add an internal tester group first. For external testers, create an external group, add the uploaded build, and submit it for TestFlight App Review. The first external build requires review before external distribution.

If you cannot provide a functioning Schoology demo account, contact Apple about an approved full-featured demo mode before relying on a simulated account. A nonfunctional placeholder is not a substitute.

## 7. After upload

- Wait for App Store Connect processing to finish; inspect the build's processing status and any email from Apple.
- Test the processed build on real iPhone and iPad hardware, including sign-in, session restore, attachments/media, messaging, comments, and permissions.
- Complete Test Information before inviting external testers.
- TestFlight builds expire after 90 days. Upload a new build when needed.

## Apple references

- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)
- [Mac Catalyst overview](https://developer.apple.com/documentation/uikit/mac-catalyst)
- [Distribute a Mac app built with Mac Catalyst](https://help.apple.com/xcode/mac/current/en.lproj/deva1159eef6.html)
- [TestFlight overview](https://developer.apple.com/testflight/)
- [Provide TestFlight test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Create an App Store Connect provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)
