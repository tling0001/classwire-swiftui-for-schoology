# Request for prior approval to use ClassWire's built-in demo mode

Apple's App Review Guideline 2.1(a) says a built-in demo mode may be used in place of a demo account when legal or security obligations prevent providing a demo account, with Apple's prior approval. This file is a preparation template, not an approval from Apple.

## How to request guidance

1. Open the [App Review page](https://developer.apple.com/app-store/review/) while signed in with the Apple Developer account that owns ClassWire.
2. Use Apple's **App Review appointment** option to request a one-on-one discussion before submitting. Explain that you need prior approval under Guideline 2.1(a), and ask how Apple wants that approval documented.
3. If Apple directs you to a support request or an existing App Review conversation, use the channel they specify and retain the written response.
4. Do not assume that creating a demo login or submitting a TestFlight build automatically grants approval.
5. Once Apple confirms the acceptable approach, include its written direction in App Review Notes and supply the demo steps. If Apple instead requires a live account, arrange an account authorized by the school or district.

## Draft request

**Subject: Prior approval request — built-in demo mode under App Review Guideline 2.1(a)**

Hello App Review,

I'm preparing ClassWire, an independent native client that lets a user access their existing Schoology account. The app displays school-managed learning information, which can include grades, coursework, messages, and other education records.

I would like to request prior approval to provide a built-in demonstration mode in place of a live Schoology demo account under App Review Guideline 2.1(a).

The reason a live account may not be appropriate is that Schoology accounts and student records are controlled by schools or districts. I cannot provide personal school credentials or expose real student records to reviewers without the required institutional authorization. [Only retain this explanation if it accurately reflects the applicable school/district policy and your circumstances.]

The demo mode uses fictional sample data and offers local simulations of app interactions. It does not connect to a Schoology account, submit coursework, send messages, or modify school records. The current implementation demonstrates the main student and teacher workflows, including assignments, submissions, grades, messages, notifications, groups, resources, and profile areas. Some server-backed and external-provider operations remain simulated or unavailable; I will clearly disclose these limitations.

Could you please confirm:
1. Whether Apple will permit this built-in demo mode under Guideline 2.1(a).
2. What level of feature parity and interaction coverage you expect for this app.
3. Whether any specific documentation or review notes are required to record the prior approval.
4. Whether you require a separate institution-authorized live test account for any Schoology-backed features.

Thank you.

## Evidence to prepare

- A concise list mapping each production feature to its demo equivalent.
- Screenshots or a short walkthrough of the demo entry and feature areas.
- A clear statement of which actions are simulated and which actions require a live Schoology account.
- Any written school/district policy or authorization restriction that supports the request, if applicable.
- The exact TestFlight build number and supported devices/OS versions once available.

## Important

The current demo is not yet a verified, production-equivalent simulator. Do not describe it as exhibiting every production feature until the feature matrix is complete and tested. Apple's prior approval is required before relying on the built-in demo instead of a demo account where Guideline 2.1(a) applies.
