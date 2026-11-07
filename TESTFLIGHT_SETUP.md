# TestFlight and App Store Connect setup for ClassWire

The iOS/iPadOS TestFlight workflow is separate from the existing registered-device Ad Hoc installer and Developer ID macOS release. The iPad app can also run on Apple-silicon Macs without Catalyst; TestFlight supports this when enabled for a tester group. The experimental Mac Catalyst TestFlight build is a separate, optional workflow. The existing native macOS app remains a separate Developer ID distribution target.

## 1. App Store Connect app record

Create one ClassWire app record with these values:

- **Platforms:** select **iOS** for the current release. Do not add the **macOS** platform until you are ready to submit a separate Mac Catalyst or native macOS App Store build. Making the iPad app available on Apple-silicon Macs is an iOS app availability setting and does not require adding the macOS platform.
- **Name:** ClassWire
- **Primary language:** English (U.S.)
- **Bundle ID:** `com.schoologytauri.app`
- **SKU:** `CLASSWIRE-IOS-001`

The SKU is an internal identifier, not shown to customers. It must be unique in your App Store Connect account and cannot be changed after the record is created. If this exact SKU is already in use, choose a different unique SKU before creating the record.

Both platforms in one record share the same Apple app identifier, SKU, and bundle ID. Apple requires a separate Xcode target and a separately uploaded build for each platform. Selecting macOS in App Store Connect does **not** automatically turn the existing native macOS app into a Mac Catalyst app.

### Mac Catalyst status

The current project has two separate targets: the iOS/iPadOS app and the existing native macOS app. The iOS target currently has Mac Catalyst disabled. The existing macOS target is a native macOS app distributed with Developer ID and notarization; it is not a Mac Catalyst build and must remain unchanged.

The iPad app can run unmodified on Apple-silicon Macs as **Designed for iPad**; this is not Mac Catalyst and does not require a separate macOS platform build.

#### Make the iPad app available on the Mac App Store

In App Store Connect → ClassWire → **Pricing and Availability** → **Apple Silicon Mac Availability**, select **Make this app available** and save. This offers the existing iPad app to compatible Apple-silicon Mac users; it does not create or upload a Catalyst/macOS target. The same iOS app code, frameworks, resources, and runtime are used. Apple calculates the minimum macOS version from the build's minimum OS settings unless you choose a higher minimum. This availability choice applies at the app level across versions.

You do not need to enable public Mac App Store availability just to test with TestFlight. For TestFlight, upload the ordinary iOS/iPadOS TestFlight build, then open TestFlight → select a tester group → Settings → enable **Test iPhone and iPad apps on Apple silicon Macs**. This is a separate group-level switch. Apple documents both settings in its [Mac availability guide](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon) and [Mac TestFlight guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-iphone-and-ipad-apps-on-macs-with-apple-silicon/).

When running as an iPad app on Mac, ClassWire keeps its iPad-style interface and controls rather than becoming a Mac-idiom Catalyst app. macOS still supplies a default menu bar, pointer/trackpad/keyboard input, window resizing and full-screen support, Mac-style scroll bars, copy and paste, and drag and drop. Check the actual layout, pointer/keyboard focus, file access, and any hardware-dependent flows on a real Apple-silicon Mac before making it publicly available. If a separate macOS app is eventually approved and released for the same app record, Apple says it replaces the iPad app for Mac users.

For testing without TestFlight, use the manual **Build iPad app for Apple-silicon Mac (Ad Hoc, no TestFlight)** workflow input. Register the Mac's UDID in the Apple Developer account, include it in an iOS Ad Hoc provisioning profile for `com.schoologytauri.app`, then enter that exact UDID when dispatching the workflow. It exports a signed IPA as a GitHub Actions artifact; on the registered Apple-silicon Mac, download the IPA and double-click it to install. This uses the existing iOS Apple Distribution certificate and does not need the four Mac App Store certificate secrets.

The experimental Mac Catalyst TestFlight build is now a separate optional workflow input, **Build optional experimental Mac Catalyst TestFlight beta**. It is not run when you select the ordinary iOS TestFlight option. It still requires the separate macOS platform and Mac App Store signing assets. The unsigned Catalyst preview is also separate and uses the dedicated `Schoology-Catalyst` target. Do not upload the existing Developer ID DMG as the macOS App Store build.

For the current plan, leave the macOS platform unadded. You can distribute and test the iPad app on Apple-silicon Macs through the iOS app record. Add the macOS platform only when you intentionally begin a separate Mac Catalyst or native macOS App Store release. Once App Review approves multiple platforms as a universal purchase, Apple says you can no longer remove an individual platform from that record.

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
4. Check **Build and upload the iOS/iPadOS TestFlight app**.
5. Leave the optional Catalyst TestFlight and Ad Hoc-only options unchecked, then run the workflow.

When this option is checked, the normal macOS, Ad Hoc IPA, and GitHub Release jobs are skipped. Only the iOS/iPadOS TestFlight job uploads the iOS build. To test it on an Apple-silicon Mac, enable the tester-group setting described above. Apple processing is asynchronous; a successful upload does not mean the build is already visible or approved.

### Test the iPad app on an Apple-silicon Mac without TestFlight

1. Find the Mac's **Provisioning UDID** in **System Settings → General → About → System Report → Hardware** (or open System Information and select Hardware).
2. Register the Mac's UDID in **Apple Developer → Certificates, Identifiers & Profiles → Devices**, selecting the Mac platform.
3. Add that Mac to an iOS Ad Hoc provisioning profile for `com.schoologytauri.app`, then regenerate/download the profile.
4. In GitHub Actions → **Run workflow**, check **Build iPad app for Apple-silicon Mac (Ad Hoc, no TestFlight)**.
5. Enter the exact Provisioning UDID in **apple_silicon_mac_udid**. Optionally enter the exact Ad Hoc profile UUID if you have multiple profiles.
6. Run the workflow and download the **ClassWire-Apple-Silicon-Mac-AdHoc** artifact.
7. Transfer the IPA to the registered Apple-silicon Mac and double-click it to install. Follow macOS's first-launch security prompt if shown.

This is a registered-device install, not an App Store/TestFlight build. The Mac UDID must be present in the embedded Ad Hoc profile.

## 6. Reviewer sign-in and Apple's beta review

A local interactive demo mode is available using the credentials in [APP_REVIEW_ACCOUNT.md](APP_REVIEW_ACCOUNT.md):

- Username: tester@classwire.app
- Password: ClassWireDemo2026!

Enter them through **Sign in with my account**. The app presents a confirmation dialog before opening the demo. No Schoology authentication request is made, and demo interactions remain local.

**Important:** Apple App Review Guideline 2.1(a) requires prior approval before using a built-in demo mode instead of a demo account when legal or security obligations prevent providing one. The demo now covers the main student and teacher workflows: Home, Courses, Upcoming, Assignments, Grades, Calendar, Messages, Notifications, Groups, People, Requests, Resources, Profile, and Settings. In Settings → Demo account type, switch between fictional Student and Teacher views to inspect student submission and teacher gradebook/grade-entry examples. It is still not a complete simulator of every production operation or backend effect. School-specific SSO, live LTI launches, actual Schoology uploads/downloads, real message delivery, push registration, and server-side record changes are not performed in demo mode. Do not submit it as a complete replacement for a live account without Apple's approval and a feature-by-feature review. If Apple requires live service access, arrange an institution-authorized Schoology test account.

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

## App encryption and export compliance

I reviewed the app's cryptography-related source and build configuration. The current implementation uses:

- **HTTPS/TLS networking** through Apple's `URLSession` and App Transport Security. The operating system negotiates and manages the secure transport.
- **OAuth 1.0 HMAC-SHA1 request signing** through Apple's CryptoKit. HMAC is a message-authentication algorithm: it authenticates request data but does not encrypt or hide that data.
- **SHA-256 digest verification** through CryptoKit for downloaded update integrity. A digest detects changes; it does not encrypt the downloaded file.
- **Apple Keychain** for storing OAuth credentials.

The project does not implement AES, ChaChaPoly, or a proprietary encryption algorithm, and I found no third-party cryptography dependency in the project configuration. Apple's CryptoKit documentation explicitly distinguishes HMAC (which does not hide data) from encryption ciphers such as AES and ChaChaPoly.

For the App Store Connect question **“What type of encryption algorithms does your app implement?”**, the source-based answer is **“None of the algorithms mentioned above.”** HMAC-SHA1 is a standard authentication code, not a standard encryption algorithm, and the app's transport encryption is provided by Apple's operating system.

If App Store Connect separately asks whether the app uses or incorporates cryptography, answer **Yes**: it uses CryptoKit HMAC/SHA-1 and SHA-256, as well as HTTPS/TLS. If it asks whether encryption is limited to Apple's operating-system implementation or whether the app only makes HTTPS calls, that describes the app's network-encryption use. Do not select the option for implementing standard encryption algorithms outside Apple's OS based solely on HMAC or SHA-256.

The iOS, Catalyst, and macOS generated Info.plists now set:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Apple documents `NO` as the correct value when an app uses no encryption or only encryption exempt from export-compliance documentation. The TestFlight workflow also validates that the exported iOS IPA contains this Boolean value before upload. If you later add your own encryption implementation or a dependency that performs encryption outside Apple's OS facilities, reassess this declaration before release.

Apple references:
- [Complying with Encryption Export Regulations](https://developer.apple.com/documentation/Security/complying-with-encryption-export-regulations)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/bundleresources/information_property_list/itsappusesnonexemptencryption)
- [CryptoKit HMAC](https://developer.apple.com/documentation/cryptokit/hmac)
- [Preventing Insecure Network Connections](https://developer.apple.com/documentation/Security/preventing-insecure-network-connections)

## Apple references

- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [Add platforms](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)
- [Mac Catalyst overview](https://developer.apple.com/documentation/uikit/mac-catalyst)
- [Distribute a Mac app built with Mac Catalyst](https://help.apple.com/xcode/mac/current/en.lproj/deva1159eef6.html)
- [TestFlight overview](https://developer.apple.com/testflight/)
- [Test iPhone and iPad apps on Macs with Apple silicon](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-iphone-and-ipad-apps-on-macs-with-apple-silicon/)
- [Register a single device](https://developer.apple.com/help/account/devices/register-a-single-device)
- [Locate device identifiers](https://developer.apple.com/documentation/xcode/locating-device-identifiers)
- [Make iPhone and iPad apps available on Apple-silicon Macs](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon)
- [Run iOS apps in macOS and distribute them with Ad Hoc or Development signing](https://developer.apple.com/documentation/apple-silicon/running-your-ios-apps-in-macos)
- [Provide TestFlight test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Create an App Store Connect provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)


## Experimental Mac Catalyst TestFlight build

The TestFlight-only workflow now builds two platform packages independently: the iOS app and an experimental Mac Catalyst app built from the iPad/iOS source. The existing native macOS target and its Developer ID distribution workflow are not changed.

Before running the TestFlight-only workflow:

1. In App Store Connect, open the ClassWire app and use **Add Platform → macOS**. This is required to receive a macOS/Catalyst build on the same app record.
2. In Apple Developer → Certificates, Identifiers & Profiles → Certificates, create both a **Mac App Distribution** certificate and a **Mac Installer Distribution** certificate. Export each certificate together with its private key as a password-protected `.p12` file.
3. Add these four GitHub Actions secrets:
   - `MAC_APP_DISTRIBUTION_CERTIFICATE_P12_BASE64`
   - `MAC_APP_DISTRIBUTION_CERTIFICATE_PASSWORD`
   - `MAC_INSTALLER_DISTRIBUTION_CERTIFICATE_P12_BASE64`
   - `MAC_INSTALLER_DISTRIBUTION_CERTIFICATE_PASSWORD`

   Base64-encode each `.p12` file for the corresponding `*_P12_BASE64` secret. Do not reuse the existing Developer ID certificate (`MACOS_CERTIFICATE_P12_BASE64`) or the iOS Apple Distribution certificate; Mac App Store signing uses the Mac App Distribution and Mac Installer Distribution certificate types.
4. In Certificates, Identifiers & Profiles → Profiles, create a **Mac App Store Connect** distribution profile for the explicit App ID `com.schoologytauri.app`, selecting the new Mac App Distribution certificate.
5. Confirm the App Store Connect API key has access to download provisioning profiles.
6. Run the TestFlight-only workflow. It uploads the iOS IPA and Mac Catalyst PKG as separate platform builds. Apple processes them independently.

The Catalyst target is a separate XcodeGen target named `Schoology-Catalyst`, but it reuses the existing iPad/iOS source. It is experimental and does not modify the separate `Schoology-macOS` native app target. Its App Store Connect upload will fail if the macOS platform or Mac App Store profile is missing.
