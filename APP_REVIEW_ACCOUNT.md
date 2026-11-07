# ClassWire App Review Sample Account

This document is a setup checklist for a real, authorized Schoology account that Apple App Review can use. It does not create an account or contain credentials. ClassWire authenticates against Schoology; a fabricated account, hard-coded login, or simulated successful sign-in would not let reviewers exercise the live app.

## Account owner and authorization

- [ ] Ask the school or district administrator to provision a dedicated Schoology test account, or obtain explicit permission to use an existing test account.
- [ ] Use a non-student, non-personal test identity where the institution supports one.
- [ ] Confirm that the account is permitted to access the Schoology API and sign in through the same normal ClassWire flow as a user.
- [ ] Confirm that the account can remain enabled throughout App Review and beta testing.
- [ ] Arrange a supported way for reviewers to complete any SSO, school selection, MFA, or other identity checks. Do not disable institutional security controls without authorization.

## Suggested sample data

Populate the account with representative, non-sensitive sample content. Avoid real student information and confidential school records.

- [ ] At least two courses with different names and course images.
- [ ] Several recent activity posts, including one with a comment thread and one with an attachment.
- [ ] Upcoming assignments, a quiz or assessment, a discussion, and a calendar event.
- [ ] Gradebook periods, categories, assignment scores, and feedback.
- [ ] Course materials including a page, a nested folder, a link, and a downloadable file.
- [ ] A group with recent activity and upcoming content.
- [ ] At least one message conversation, with permission to send a reply.
- [ ] Notifications and a profile with a non-sensitive avatar.
- [ ] A supported audio/video sample and a PDF or image attachment, if those features are part of the review.

## Verify before submitting

- [ ] Sign out of ClassWire, then sign in from a clean installation using the dedicated account.
- [ ] Confirm that the school/domain selection and SSO path are clear to someone unfamiliar with the institution.
- [ ] Test the exact username/password and MFA instructions that will be entered in App Store Connect.
- [ ] Confirm that the account is not locked, expired, rate-limited, or waiting for an administrator approval.
- [ ] Verify that the sample content is still present and that the account has the permissions needed for the listed workflows.

## App Store Connect review notes

In the relevant TestFlight build's **Test Information → Test Details → TestFlight App Review Information**, mark sign-in as required and enter the working credentials. Include:

- School or organization name and the exact sign-in route.
- Username and password for the dedicated test account.
- Whether the reviewer must choose a school/domain or use a specific SSO button.
- Any necessary MFA/access instructions and a monitored contact for access problems.

Do not put the password in this repository, source code, release notes, or GitHub Actions variables. Enter it only in the appropriate private App Store Connect review fields.
