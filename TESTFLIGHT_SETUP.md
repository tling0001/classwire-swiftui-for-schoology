# TestFlight setup for ClassWire

This workflow uploads an **iOS/iPadOS** beta to App Store Connect. It is separate from the existing registered-device Ad Hoc installer and Developer ID macOS release.

## 1. App Store Connect app record

1. In App Store Connect, create or open the ClassWire app record.
2. Set the bundle ID to exactly `com.schoologytauri.app`. The bundle ID is intentionally retained for existing installations and Schoology's OAuth callback.
3. Use the current marketing version from `VERSION` (currently `2026.10.0`). The workflow derives the Apple build number from the `-port.N` suffix.
4. Confirm the app record is enabled for iOS/iPadOS and that required account agreements are current.

An app record is required before the first upload. Apple creates the TestFlight build record after the first successful upload and processing.

## 2. Apple signing assets

The TestFlight workflow uses App Store Connect distribution signing, not Ad Hoc signing:

- An active **Apple Distribution** certificate exported as a password-protected `.p12`.
- An active **App Store Connect** provisioning profile for the explicit App ID `com.schoologytauri.app`, associated with that distribution certificate.
- The existing App Store Connect API key with permission to access signing assets and upload builds.

The workflow downloads the App Store Connect profile at run time using the API key and checks that its App ID/team match, `get-task-allow` is false, and it does not contain a device list.

## 3. GitHub Actions secrets and variables

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

## 4. Run only the TestFlight build

1. Open the repository's **Actions** tab.
2. Select **Build and release ClassWire SwiftUI**.
3. Choose **Run workflow** on the `main` branch.
4. Check **Build and upload only the iOS TestFlight package (skips macOS and Ad Hoc)**.
5. Leave **Build and publish only the iOS Ad Hoc package** unchecked, then run the workflow.

When TestFlight is checked, the macOS, Ad Hoc IPA, and GitHub Release jobs are skipped. The dedicated TestFlight job archives, exports, validates, and uploads the App Store Connect IPA. Apple processing is asynchronous; a successful upload does not mean the build is already visible or approved.

## 5. Reviewer sign-in and Apple's beta review

ClassWire's **Sign in with my account** option authenticates against Schoology. A fake username/password, placeholder credentials, or a bypass that merely simulates a successful sign-in would not give App Review access to the actual account-based functionality, so the app does not embed one.

Before requesting external TestFlight review:

1. Arrange a dedicated Schoology test account with access needed to exercise the app. Confirm it can sign in using **Sign in with my account** and remains active for the review period.
2. If the account is controlled by a school or district, obtain authorization from that administrator. Do not use a student's or another person's account without permission.
3. In App Store Connect → ClassWire → TestFlight → Test Information, enter the beta description and a monitored feedback email.
4. In the build's **TestFlight App Review Information**, indicate whether sign-in is required and provide the working demo username/password and any school/domain selection instructions. Include required MFA or access steps in review notes.
5. Add an internal tester group first. For external testers, create an external group, add the uploaded build, and submit it for TestFlight App Review. The first external build requires review before external distribution.

If you cannot provide a functioning Schoology demo account, contact Apple about an approved full-featured demo mode before relying on a simulated account. A nonfunctional placeholder is not a substitute.

## 6. After upload

- Wait for App Store Connect processing to finish; inspect the build's processing status and any email from Apple.
- Test the processed build on real iPhone and iPad hardware, including sign-in, session restore, attachments/media, messaging, comments, and permissions.
- Complete Test Information before inviting external testers.
- TestFlight builds expire after 90 days. Upload a new build when needed.

## Apple references

- [TestFlight overview](https://developer.apple.com/testflight/)
- [Provide TestFlight test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Create an App Store Connect provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)
