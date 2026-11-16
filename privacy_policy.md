# ClassWire Privacy Policy

**Last updated: November 11, 2026**

ClassWire is an independent client for accessing a user's existing Schoology account. This policy explains what information the app handles, where it is sent, how it is stored, and the choices available to users.

## 1. Who operates ClassWire

ClassWire is maintained as an independent software project. The developer does not operate a ClassWire account database, analytics service, advertising network, or push-notification server. The app communicates with Schoology and other services described below to provide its features.

ClassWire is not affiliated with, authorized, maintained, sponsored, or endorsed by PowerSchool Group LLC or Schoology. Schoology and related names are trademarks of their respective owners.

## 2. Information the app handles

Depending on the features you use, ClassWire may handle:

- **Sign-in information:** the username and password you enter for direct sign-in, a QR sign-in value you scan, or authentication information returned by your school's sign-in provider. Direct sign-in information is sent to Schoology's authentication service. For school/browser sign-in, authentication is handled by Schoology and the school's identity provider.
- **Authentication tokens:** Schoology OAuth tokens and related credentials used to make authenticated requests. ClassWire stores the OAuth credentials in the device Keychain rather than storing the account password.
- **Schoology account and learning information:** profile details, school and course memberships, course materials, assignments, grades, feedback, calendar events, group information, posts, comments, likes, messages, notifications, and resource metadata that the app requests and displays.
- **Files and attachments:** files you choose to upload for supported assignment submissions or messages, files you attach to AI prompts (including images, PDFs, and supported text documents), and files you choose to download or preview. Text may be extracted from supported documents to make their contents available to an AI provider.
- **AI prompts and responses:** prompts you enter, AI conversation text, images or documents you attach, and relevant Schoology information retrieved by AI tools (which can include course details, assignments, grades, messages, materials, and other account data). AI-generated text and images are also handled by the app.
- **AI provider and Google Cloud setup information:** the AI provider you select, model and connection settings, provider API keys, and (if you configure Gemini automatically) your Google account email, Google OAuth authorization, Google Cloud project identifiers, and Gemini API key.
- **Notification registration information:** when you enable push notifications, Apple provides an APNs device token. ClassWire sends that token to Schoology together with the platform, device name, operating-system version, and app version so Schoology can associate the device with your account for notifications.
- **App preferences:** settings such as appearance, selected Schoology region, and notification preferences.

ClassWire does not need to handle every category listed above for every user. The information handled depends on your account, school permissions, and the features you choose to use.

## 3. Where information is sent

### Schoology and your school

ClassWire sends authentication requests and authenticated API requests to Schoology's U.S. or Canadian services, depending on the server region you select. This includes requests to read or update Schoology content. When you post a comment, send a message, submit coursework, upload a file, or change a supported setting, the corresponding information is sent to Schoology.

When you use school sign-in, Schoology and your school's identity provider may process information under their own privacy terms.

### ClassWire AI and external AI providers

ClassWire AI sends the prompt and the relevant conversation context to the AI provider and model you select. Depending on your request and the tools the assistant uses, that context can include Schoology course information, assignments, grades, feedback, messages, materials, or other information retrieved from your signed-in account. If you attach an image, PDF, or supported text file, its image data or extracted text is sent to the selected provider so it can answer your request. AI-generated responses and any generated images are returned to ClassWire for display.

Supported provider routes include Google Gemini, OpenAI, Anthropic, and Puter. If you configure Ollama, prompts and supported extracted document text are sent to the Ollama server URL you enter; that server may be on your own device, your local network, or a remote host. Image input is supported only by compatible provider/model combinations. Puter currently receives prompt text and extracted text from supported text-file attachments; it does not accept image or PDF attachments. Each provider processes information under its own terms, privacy policy, and retention settings. ClassWire does not operate these AI services and cannot control their retention, model-training, or deletion practices. Review the selected provider's terms before sending sensitive education information. Do not attach information unless you are authorized to share it.

When you ask ClassWire AI to perform a Schoology action, the app displays a proposal and requires your explicit confirmation. If you confirm a file-based assignment submission, ClassWire uploads the selected attachment files to Schoology and creates the submission revision. The files are not submitted merely because you attached them to an AI prompt.

For automatic Gemini setup, you may authorize ClassWire to access your Google account for Google Cloud project and API-key management. ClassWire uses Google Cloud APIs to find or create a project named ClassWire AI, enable required services, and create or reuse a Gemini API key. Google processes the OAuth authorization and Cloud management requests under Google's terms. The Google refresh token and resulting Gemini API key are stored in Apple Keychain. The Gemini API key is sent to Google's Gemini service when you use Gemini; it is not sent to other AI providers.

### Schoology web pages and external learning tools

Some Schoology features open web content in an embedded browser. ClassWire may provide Schoology session cookies to that browser so it can display the requested Schoology page. Schoology resource apps, LTI tools, linked websites, and other external services may receive information necessary to launch or use those services. Those providers operate under their own privacy policies and terms. Review them before using an external tool.

### Apple Push Notification service

If you enable notifications, ClassWire registers with Apple Push Notification service (APNs) and registers the resulting device token with Schoology. Apple and Schoology process the information needed to deliver notifications. You can turn notifications off in ClassWire or in your device's system settings.

### GitHub

ClassWire checks GitHub for published app update information and downloads release assets from GitHub when you choose to update. GitHub receives ordinary network request information, such as your IP address and request metadata. ClassWire does not send your Schoology grades, messages, profile, or course data to GitHub for update checks.

## 4. Local storage and security

- OAuth credentials are stored in the Apple Keychain with device-only accessibility settings.
- App preferences and AI conversation text are stored locally using the platform's preferences storage. Attached file bytes are held in memory while the AI request and current assistant session are active; they are not included in the saved conversation history.
- API keys for supported AI providers and the Google refresh token used for Gemini Cloud setup are stored in Apple Keychain. The Google account email and non-secret provider/model preferences are stored locally.
- Schoology content is generally loaded for display while the app is running; some views and services may retain temporary in-memory data during the session.
- Schoology web-session cookies are provided to the system WebKit website data store for embedded web pages. WebKit may retain website data according to its storage behavior.
- Files you explicitly save or export are stored at the location you choose.

Network requests to Schoology and GitHub use HTTPS. Keychain storage and HTTPS reduce exposure, but no software or transmission method can be guaranteed completely secure.

## 5. Analytics, advertising, and sale of information

The current ClassWire app implementation does not include an advertising SDK, third-party analytics SDK, or cross-app tracking framework. The developer does not sell personal information or use Schoology learning information for advertising.

This does not prevent Schoology, Apple, GitHub, a school identity provider, or an external learning-tool provider from processing information as described in their own policies when you use their services.

## 6. Retention and deletion

- OAuth credentials remain in Keychain until you sign out or the credentials are otherwise replaced or removed. Signing out deletes the locally stored OAuth credentials and asks Schoology to unregister the active push token when possible.
- App preferences and saved AI conversation text remain on the device until changed, deleted in the app where supported, or the app's local data is removed. AI attachment bytes are not saved with conversation history and are released with the active session, subject to normal operating-system behavior.
- Signing out clears locally stored AI conversations, provider/model preferences, captured page context, all AI provider API keys, the Google refresh token, and Google account metadata. The app also attempts to sign out of Puter. A Gemini API key created in Google Cloud remains subject to Google's Cloud API-key management and deletion controls. A Gemini key created in Google Cloud remains subject to Google's Cloud API-key management and deletion controls.
- Temporary data held in memory is released as the app session ends, subject to normal operating-system behavior.
- WebKit cookies and website data may remain in WebKit's website data store; signing out of ClassWire does not currently guarantee that every embedded-browser cookie is immediately erased.
- Files downloaded or exported by you remain wherever you saved them until you delete them.
- Information already submitted to Schoology, your school, Apple, GitHub, or an external learning-tool provider is governed by that service's retention and deletion practices. Signing out of ClassWire does not delete records from those services.

To stop ClassWire from accessing your Schoology account, sign out and, where available, revoke the app's authorization through your Schoology account or school administrator. To stop push notifications, disable them in ClassWire and/or your device settings. For Schoology account data or education-record requests, contact your school or Schoology; the ClassWire developer cannot delete records held by those organizations.

## 7. Student and school-managed information

ClassWire may display education records and other information associated with school-managed Schoology accounts. Schools and school administrators control access to those accounts and the information available through them. Users should follow their school's policies and obtain any required authorization before connecting an account or sharing school information with an external learning tool.

## 8. Children's privacy

ClassWire is an access client and does not operate a separate student profile service. Schoology accounts may belong to students, including minors. The app handles information made available through the connected Schoology account as described in this policy. Parents, guardians, and schools should direct questions about the underlying student account, education records, and school authorization to the school or Schoology.

## 9. Changes to this policy

This policy may be updated when app functionality or data practices change. The latest version will be published in the ClassWire source repository. The “Last updated” date above identifies the current revision.

## 10. Contact

For questions about ClassWire's implementation or this policy, contact:

**tling0001@mymail.lausd.net**
