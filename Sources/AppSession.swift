import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppSession {
    var auth: SchoologyAuth?
    var user: SchoologyUser?
    var peopleDirectoryEnabled = false
    var destination: AppDestination = .home
    var pendingPersonProfileID: String?
    var homeSection: HomeSection = .recent
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var courses: [SchoologyCourse] = []
    var groups: [SchoologyGroup] = []
    var notifications: [SchoologyNotification] = []
    var resourceCollections: [SchoologyResourceCollection] = []
    var resourceApps: [SchoologyResourceCollection] = []
    var hasLoadedResources = false
    var isLoadingResources = false
    var resourcesError: String?
    var userGradeCourses: [SchoologyUserGradeCourse] = []
    var hasLoadedUserGrades = false
    var isLoadingUserGrades = false
    var userGradesError: String?
    var calendarMonthEvents: [SchoologyUpcomingEvent] = []
    var calendarUpcomingEvents: [SchoologyUpcomingEvent] = []
    var calendarLoadedMonth = ""
    var hasLoadedCalendarUpcoming = false
    var isLoadingCalendar = false
    var calendarError: String?
    var hasLoadedNotifications = false
    var isLoadingNotifications = false
    var isLoadingMoreNotifications = false
    var notificationsHasMore = true
    var notificationsError: String?
    var messageFolder = SchoologyMessageFolder.inbox
    var cachedMessagesByFolder: [String: [SchoologyMessage]] = [:]
    var messageErrors: [String: String] = [:]
    var activities: [SchoologyActivity] = []
    var upcomingEvents: [SchoologyUpcomingEvent] = []
    var hasLoadedHomeActivities = false
    var hasLoadedHomeCourses = false
    var hasLoadedHomeUpcoming = false
    var homeActivitiesError: String?
    var homeCoursesError: String?
    var homeUpcomingError: String?
    var schoolNames: [String: String] = [:]
    var appearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "schoology.appearance") }
    }
    var canadianServer = UserDefaults.standard.bool(forKey: "schoology.canadian")

    private let api = SchoologyAPI.shared
    private let schoolBrowserAuthenticator = SchoolBrowserAuthenticator()

    init() {
        appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "schoology.appearance") ?? "") ?? .system
        auth = KeychainStore.loadAuth()
        if let auth {
            Task { await restore(auth) }
        }
    }

    var isSignedIn: Bool { auth != nil }

    func showPersonProfile(userID: String) {
        guard !userID.isEmpty else { return }
        pendingPersonProfileID = userID
    }

    func restore(_ credentials: SchoologyAuth) async {
        isLoading = true
        defer { isLoading = false }
        do {
            await api.setCanadianServer(canadianServer)
            let profile = try await api.currentUser(auth: credentials)
            auth = credentials
            user = profile
            await refreshPeopleDirectoryAvailability(auth: credentials)
            await refresh()
        } catch {
            KeychainStore.clear()
            auth = nil
            errorMessage = error.localizedDescription
        }
    }

    func signIn(username: String, password: String, schoolID: String?, canadian: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            canadianServer = canadian
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
            await api.setCanadianServer(canadian)
            let credentials = try await api.login(username: username, password: password, schoolID: schoolID)
            try await establishSession(credentials)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithQRCode(_ qrCode: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            await api.setCanadianServer(canadianServer)
            let credentials = try await api.loginWithQRCode(qrCode)
            try await establishSession(credentials)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelSchoolSignIn() {
        schoolBrowserAuthenticator.cancel()
    }

    func signInThroughSchool(domain: String, canadian: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            canadianServer = canadian
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
            await api.setCanadianServer(canadian)
            let pending = try await api.prepareSchoolBrowserLogin(domain: domain)
            let callback = try await schoolBrowserAuthenticator.authenticate(using: pending.authorizationURL)
            let credentials = try await api.completeSchoolBrowserLogin(pending, callbackURL: callback)
            try await establishSession(credentials)
        } catch is CancellationError {
            // Returning to the school picker cancels authentication intentionally.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func establishSession(_ credentials: SchoologyAuth) async throws {
        let profile = try await api.currentUser(auth: credentials)
        let verifiedCredentials = SchoologyAuth(
            token: credentials.token,
            secret: credentials.secret,
            userID: profile.id
        )
        KeychainStore.save(verifiedCredentials)
        auth = verifiedCredentials
        user = profile
        await refreshPeopleDirectoryAvailability(auth: verifiedCredentials)
        destination = .home
        homeSection = .recent
        await refresh()
    }

    private func fetchHomeData(path: String, auth: SchoologyAuth, params: [String: String] = [:]) async -> (Data?, String?) {
        do {
            return (try await api.get(path, auth: auth, params: params), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    func refresh() async {
        guard let auth else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let activityRequest = fetchHomeData(path: "recent", auth: auth, params: [
            "start": "0", "limit": "20", "with_attachments": "TRUE", "richtext": "1"
        ])
        async let courseRequest = fetchHomeData(path: "users/\(auth.userID)/sections", auth: auth, params: ["limit": "100"])
        async let groupRequest = fetchHomeData(path: "users/\(auth.userID)/groups", auth: auth, params: ["limit": "100"])
        async let upcomingRequest = fetchHomeData(path: "users/\(auth.userID)/events", auth: auth, params: [
            "start_date": Self.apiDate(Date()), "start": "0", "limit": "50"
        ])

        let (activityResult, courseResult, groupResult, upcomingResult) = await (
            activityRequest, courseRequest, groupRequest, upcomingRequest
        )

        let (activityData, activityError) = activityResult
        hasLoadedHomeActivities = true
        homeActivitiesError = activityError
        if let activityData {
            activities = SchoologyActivity.decodeList(Self.object(activityData))
            await hydrateActivityAuthors(auth: auth)
        }

        let (courseData, courseError) = courseResult
        hasLoadedHomeCourses = true
        homeCoursesError = courseError
        if let courseData {
            courses = SchoologyCourse.decodeList(Self.object(courseData))
        }

        if let groupData = groupResult.0 {
            groups = SchoologyGroup.decodeList(Self.object(groupData))
        }

        let (upcomingData, upcomingError) = upcomingResult
        hasLoadedHomeUpcoming = true
        homeUpcomingError = upcomingError
        if let upcomingData {
            upcomingEvents = SchoologyUpcomingEvent.decodeList(Self.object(upcomingData))
                .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        }
    }

    func loadCoursePage(courseID: String, pageID: String) async throws -> SchoologyPage {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(courseID)/pages/\(pageID)", auth: auth)
        let response = Self.object(data)
        let page = response["page"] as? [String: Any] ?? response
        let host = canadianServer ? "app.schoologyca.com" : "app.schoology.com"
        guard let baseURL = URL(string: "https://\(host)/") else {
            throw SchoologyAPIError.invalidResponse
        }
        return SchoologyPage(
            title: SchoologyValue.string(page["title"], fallback: "Page"),
            body: SchoologyValue.string(page["body"] ?? page["description"] ?? page["content"]),
            baseURL: baseURL
        )
    }

    func loadCourseMaterials(courseID: String, folderID: String = "0") async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("courses/\(courseID)/folder/\(folderID)", auth: auth)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["folder-item", "folder_item", "folderItems", "items", "documents"])
    }

    func loadCourseUpdates(courseID: String) async throws -> [SchoologyActivity] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(courseID)/updates", auth: auth, params: ["start": "0", "limit": "50", "with_attachments": "TRUE", "richtext": "1"])
        var updates = SchoologyActivity.decodeList(Self.object(data))
        for index in updates.indices {
            updates[index].commentRealm = "sections"
            updates[index].commentRealmID = courseID
        }
        return await hydratedActivityAuthors(updates, auth: auth)
    }

    func loadCourseAssignments(courseID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(courseID)/assignments", auth: auth, params: ["start": "0", "limit": "100", "with_attachments": "TRUE", "richtext": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["assignment", "assignments", "items"])
    }

    func loadCourseMembers(courseID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(courseID)/enrollments", auth: auth, params: ["start": "0", "limit": "200", "enrollment_status": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["enrollment", "enrollments", "user", "users"])
    }

    func loadCourseApps(courseID: String) async throws -> [SchoologyCourseApp] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.getV2("sections/\(courseID)/applications", auth: auth)
        return SchoologyCourseApp.decodeList(data)
    }

    func launchCourseApp(_ app: SchoologyCourseApp, courseID: String) async throws -> URL {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        guard let launchURL = app.launchURL else { throw SchoologyAPIError.invalidResponse }
        return try await api.launchCourseApp(launchURL, sectionID: courseID, auth: auth)
    }

    func launchResourceApp(_ app: SchoologyResourceCollection) async throws -> URL {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        return try await api.launchResourceApp(appID: app.id, auth: auth)
    }

    func loadPeopleDirectory() async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        do {
            let data = try await api.get("users", auth: auth, params: ["start": "0", "limit": "200"])
            return SchoologyProfileItem.decodeList(Self.object(data), keys: ["user", "users", "items"])
                .sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
        } catch let error as SchoologyAPIError {
            guard case .http(403, _) = error else { throw error }
        }
        let sectionData = try await api.get("users/\(auth.userID)/sections", auth: auth, params: ["limit": "100"])
        let sections = SchoologyCourse.decodeList(Self.object(sectionData))
        var peopleByID: [String: SchoologyProfileItem] = [:]
        if let user {
            peopleByID[user.id] = SchoologyProfileItem(
                id: user.id, title: user.nameDisplay, body: "", subtitle: "", url: nil,
                isAdmin: false, kind: "person", collectionID: nil, pictureURL: user.pictureURL
            )
        }
        for section in sections.prefix(30) {
            guard let data = try? await api.get("sections/\(section.id)/enrollments", auth: auth,
                params: ["enrollment_status": "1", "limit": "200"]) else { continue }
            let members = SchoologyProfileItem.decodeList(Self.object(data), keys: ["enrollment", "enrollments", "user", "users"])
            for member in members where !member.id.isEmpty { peopleByID[member.id] = member }
        }
        return peopleByID.values.sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
    }

    func loadCourseGradebook(courseID: String) async throws -> SchoologyGradebook {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        async let sectionRequest = api.get("sections/\(courseID)", auth: auth)
        async let periodsRequest = api.get("sections/\(courseID)/grading_periods", auth: auth)
        async let categoriesRequest = api.get("sections/\(courseID)/grading_categories", auth: auth)
        async let itemsRequest = api.get("sections/\(courseID)/grade_items", auth: auth, params: ["limit": "2000"])
        async let userGradesRequest = api.get("users/\(auth.userID)/grades", auth: auth, params: ["section_id": courseID])
        let (sectionData, periodsData, categoriesData, itemsData, userGradesData) =
            try await (sectionRequest, periodsRequest, categoriesRequest, itemsRequest, userGradesRequest)

        let section = Self.object(sectionData)
        let gradeItems = SchoologyValue.list(Self.object(itemsData), keys: ["assignment", "assignments", "items"])
        let userSections = SchoologyValue.list(Self.object(userGradesData), keys: ["section", "sections", "items"])
        let current = userSections.first {
            SchoologyValue.string($0["section_id"] ?? $0["sectionId"] ?? $0["id"]) == courseID
        } ?? (userSections.count == 1 ? userSections.first : nil)

        var gradeByAssignmentID: [String: [String: Any]] = [:]
        for period in SchoologyValue.list(current?["period"] ?? current?["periods"], keys: ["period", "periods", "items"]) {
            for grade in SchoologyValue.list(period["assignment"] ?? period["assignments"], keys: ["assignment", "assignments", "items"]) {
                let id = SchoologyValue.string(grade["assignment_id"] ?? grade["assignmentId"] ?? grade["id"])
                if !id.isEmpty { gradeByAssignmentID[id] = grade }
            }
        }

        let rawCategories = SchoologyValue.list(Self.object(categoriesData), keys: ["grading_category", "grading_categories", "category", "categories", "items"])
        let rawPeriods = SchoologyValue.list(Self.object(periodsData), keys: ["grading_period", "grading_periods", "grade_period", "gradePeriod", "period", "periods", "items"])
        let categoryMap = Dictionary(rawCategories.compactMap { row -> (String, [String: Any])? in
            let id = SchoologyValue.string(row["id"])
            return id.isEmpty ? nil : (id, row)
        }, uniquingKeysWith: { first, _ in first })
        let periodMap = Dictionary(rawPeriods.compactMap { row -> (String, [String: Any])? in
            let id = SchoologyValue.string(row["id"])
            return id.isEmpty ? nil : (id, row)
        }, uniquingKeysWith: { first, _ in first })

        let rawFinal = current?["final_grade"] ?? current?["finalGrade"] ?? current?["final_grades"] ?? current?["finalGrades"]
        let finalRecord = (rawFinal as? [[String: Any]])?.first ?? (rawFinal as? [String: Any])
        let finalPeriods = SchoologyValue.list(finalRecord?["period"] ?? finalRecord?["periods"] ?? finalRecord?["final_period"] ?? finalRecord?["finalPeriod"], keys: ["period", "periods", "items"])
        let finalPeriod = finalPeriods.first { SchoologyValue.string($0["period_id"] ?? $0["periodId"]) == "final" } ?? finalPeriods.first
        let overallRaw = finalPeriod?["override_str"] ?? finalPeriod?["overrideStr"] ??
            finalPeriod?["override_string"] ?? finalPeriod?["overrideString"] ??
            finalRecord?["override_str"] ?? finalRecord?["overrideStr"] ??
            finalRecord?["override_string"] ?? finalRecord?["overrideString"] ??
            finalPeriod?["grade"] ?? finalRecord?["grade"] ??
            finalRecord?["calculated_grade"] ?? finalRecord?["calculatedGrade"]
        let overall = overallRaw == nil || overallRaw is NSNull ? "—" : SchoologyValue.string(overallRaw, fallback: "—")
        let overallCommentRaw = finalRecord?["comment"] ?? finalPeriod?["comment"]
        let overallComment = SchoologyValue.plainText(SchoologyValue.string(
            (overallCommentRaw as? [String: Any])?["comment"] ?? (overallCommentRaw as? [String: Any])?["body"] ?? overallCommentRaw
        ))

        var grouped: [String: [String: [SchoologyGradeAssignment]]] = [:]
        for item in gradeItems {
            let id = SchoologyValue.string(item["id"] ?? item["assignment_id"] ?? item["assignmentId"])
            guard !id.isEmpty else { continue }
            let grade = gradeByAssignmentID[id] ?? [:]
            let periodID = SchoologyValue.string(item["grading_period_id"] ?? item["grading_period"] ?? item["period_id"] ?? item["periodId"], fallback: "0")
            let categoryID = SchoologyValue.string(item["grading_category_id"] ?? item["grading_category"] ?? item["category_id"] ?? item["categoryId"], fallback: "0")
            let rawScore = grade["grade"] ?? grade["calculated_grade"] ?? grade["score"] ?? grade["override_numeric"] ?? grade["overrideNumeric"]
            let score = rawScore == nil || rawScore is NSNull ? "—" : SchoologyValue.string(rawScore, fallback: "—")
            let maxPoints = SchoologyValue.string(item["max_points"] ?? item["maxPoints"] ?? grade["max_points"] ?? grade["maxPoints"])
            let rawComment = grade["comment"] ?? grade["teacher_comment"] ?? grade["teacherComment"]
            let comment = SchoologyValue.plainText(SchoologyValue.string(
                (rawComment as? [String: Any])?["comment"] ?? (rawComment as? [String: Any])?["body"] ?? rawComment
            ))
            let assignment = SchoologyGradeAssignment(
                id: id,
                title: SchoologyValue.string(item["title"] ?? item["assignment_title"] ?? item["assignmentTitle"], fallback: "Assignment"),
                grade: score,
                maxPoints: maxPoints,
                due: SchoologyValue.string(item["due"] ?? item["due_date"] ?? item["dueDate"]),
                comment: comment,
                itemType: SchoologyValue.string(item["type"] ?? item["template_type"] ?? item["type_name"] ?? item["typeName"], fallback: "assignment")
            )
            grouped[periodID, default: [:]][categoryID, default: []].append(assignment)
        }

        var gradePeriods: [SchoologyGradePeriod] = []
        let orderedPeriods = rawPeriods.sorted {
            let lhs = SchoologyValue.integer($0["sort_order"] ?? $0["sortOrder"])
            let rhs = SchoologyValue.integer($1["sort_order"] ?? $1["sortOrder"])
            return lhs == rhs
                ? SchoologyValue.string($0["title"]).localizedCaseInsensitiveCompare(SchoologyValue.string($1["title"])) == .orderedAscending
                : lhs < rhs
        }
        let periodIDs = Set(grouped.keys)
        for period in orderedPeriods {
            let periodID = SchoologyValue.string(period["id"])
            guard periodIDs.contains(periodID) else { continue }
            let categoryGroups = grouped[periodID] ?? [:]
            let categoryIDs = Set(categoryGroups.keys)
            var categories: [SchoologyGradeCategory] = []
            for category in rawCategories {
                let categoryID = SchoologyValue.string(category["id"])
                guard categoryIDs.contains(categoryID) else { continue }
                categories.append(SchoologyGradeCategory(
                    id: categoryID,
                    title: SchoologyValue.string(category["title"] ?? category["name"], fallback: "Category"),
                    weight: SchoologyValue.string(category["weight"] ?? category["percent"] ?? category["percentage"] ?? category["weight_percent"] ?? category["weightPercentage"]),
                    assignments: (categoryGroups[categoryID] ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                ))
            }
            if let ungrouped = categoryGroups["0"] {
                categories.append(SchoologyGradeCategory(
                    id: "\(periodID)-ungrouped",
                    title: "Ungraded",
                    weight: "",
                    assignments: ungrouped.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                ))
            }
            for categoryID in categoryIDs where categoryID != "0" && categoryMap[categoryID] == nil {
                categories.append(SchoologyGradeCategory(
                    id: categoryID,
                    title: "Category",
                    weight: "",
                    assignments: (categoryGroups[categoryID] ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                ))
            }
            gradePeriods.append(SchoologyGradePeriod(
                id: periodID,
                title: SchoologyValue.string(period["title"] ?? period["name"], fallback: "Grading Period"),
                categories: categories
            ))
        }
        for periodID in grouped.keys.sorted() where !periodMap.keys.contains(periodID) {
            let categoryGroups = grouped[periodID] ?? [:]
            let categories = categoryGroups.keys.sorted().map { categoryID in
                SchoologyGradeCategory(
                    id: "\(periodID)-\(categoryID)",
                    title: categoryID == "0" ? "Ungraded" : SchoologyValue.string(categoryMap[categoryID]?["title"] ?? categoryMap[categoryID]?["name"], fallback: "Category"),
                    weight: SchoologyValue.string(categoryMap[categoryID]?["weight"] ?? categoryMap[categoryID]?["percent"]),
                    assignments: (categoryGroups[categoryID] ?? []).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                )
            }
            gradePeriods.append(SchoologyGradePeriod(id: periodID, title: periodID == "0" ? "Other" : "Grading Period", categories: categories))
        }

        let sectionPayload = (section["section"] as? [String: Any]) ?? section
        let defaultScale = SchoologyValue.string((sectionPayload["options"] as? [String: Any])?["default_grading_scale_id"])
        return SchoologyGradebook(
            courseID: courseID,
            overallGrade: overall,
            overallComment: overallComment,
            gradingScaleID: defaultScale,
            periods: gradePeriods
        )
    }

    func loadCourseGrades(courseID: String) async throws -> [SchoologyProfileItem] {
        let gradebook = try await loadCourseGradebook(courseID: courseID)
        return gradebook.periods.flatMap { period in
            period.categories.flatMap { category in
                category.assignments.map { assignment in
                    SchoologyProfileItem(
                        id: assignment.id,
                        title: assignment.title,
                        body: assignment.grade,
                        subtitle: [period.title, category.title, assignment.due.isEmpty ? nil : "Due " + assignment.due].compactMap { $0 }.joined(separator: " • "),
                        url: nil, isAdmin: false, kind: assignment.itemType, collectionID: nil
                    )
                }
            }
        }
    }

    func loadResources(force: Bool = false) async {
        guard let auth, !isLoadingResources else { return }
        if hasLoadedResources && !force { return }
        isLoadingResources = true
        resourcesError = nil
        defer { isLoadingResources = false }
        do {
            async let collectionsRequest = api.get("collections", auth: auth, params: ["limit": "200"])
            async let appsRequest = try? await api.get("resource_apps", auth: auth, params: ["limit": "200"])
            let (collectionsData, appsData) = try await (collectionsRequest, appsRequest)
            let all = SchoologyResourceCollection.decodeList(Self.object(collectionsData), keys: ["collection", "collections", "collection_list", "items"])
            let apps = SchoologyResourceCollection.decodeList(Self.object(appsData ?? Data()), keys: ["resource_apps", "resourceApps", "collection", "collections", "items"])
            var mine: [SchoologyResourceCollection] = []
            var shared: [SchoologyResourceCollection] = []
            var groups: [SchoologyResourceCollection] = []
            for item in all {
                if item.ownerID == auth.userID && item.realm.isEmpty {
                    mine.append(item.withCategory(.mine))
                } else if item.sharedCount > 0 {
                    shared.append(item.withCategory(.shared))
                } else if item.realm == "group" {
                    groups.append(item.withCategory(.groups))
                }
            }
            resourceCollections = mine + shared + groups
            resourceApps = apps.map { $0.withCategory(.apps) }
            hasLoadedResources = true
        } catch {
            resourcesError = error.localizedDescription
            hasLoadedResources = true
        }
    }

    func loadResourceItems(collectionID: String, folderID: String? = nil) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        var params = ["start": "0", "limit": "200", "with_attachments": "TRUE"]
        if let folderID, !folderID.isEmpty, folderID != "0" { params["f"] = folderID }
        let data = try await api.get("collections/\(collectionID)/resources", auth: auth, params: params)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["resource", "resources", "resource_list", "items"])
    }


    func downloadAttachment(_ attachment: SchoologyAttachment, forViewing: Bool = false) async throws -> URL {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let sourceURL = forViewing ? (attachment.viewURL ?? attachment.url) : attachment.url
        let (data, mimeType) = try await api.attachmentData(sourceURL, auth: auth)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchoologyAttachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var filename = URL(fileURLWithPath: attachment.title).lastPathComponent
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        if filename.isEmpty || filename == "." { filename = "Attachment" }
        if forViewing, attachment.viewURL != nil {
            let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            filename = base + ".pdf"
        } else if URL(fileURLWithPath: filename).pathExtension.isEmpty {
            let ext = sourceURL.pathExtension
            if !ext.isEmpty { filename += "." + ext }
            else if mimeType.lowercased().contains("pdf") { filename += ".pdf" }
        }
        let destination = directory.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func loadUserGradeCourses(force: Bool = false) async {
        guard let auth, !isLoadingUserGrades else { return }
        if hasLoadedUserGrades && !force { return }
        isLoadingUserGrades = true
        userGradesError = nil
        defer { isLoadingUserGrades = false }
        do {
            let data = try await api.get("users/\(auth.userID)/grades", auth: auth)
            userGradeCourses = SchoologyUserGradeCourse.decodeList(Self.object(data))
            hasLoadedUserGrades = true
        } catch {
            userGradesError = error.localizedDescription
            hasLoadedUserGrades = true
        }
    }

    func loadCalendarMonth(_ month: Date, force: Bool = false) async {
        guard let auth, !isLoadingCalendar else { return }
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }
        let key = String(Self.apiDate(interval.start).prefix(7))
        if !force && calendarLoadedMonth == key { return }

        isLoadingCalendar = true
        calendarError = nil
        defer { isLoadingCalendar = false }

        do {
            // Match Android CalendarApiHelper/EventCalls: date bounds are
            // start_date/end_date, while start is the result offset.
            // Android requests 20 events per page and keeps fetching until
            // the final short page.
            var offset = 0
            var seenIDs = Set<String>()
            var monthEvents: [SchoologyUpcomingEvent] = []
            let pageSize = 20

            while true {
                let data = try await api.get("users/\(auth.userID)/events", auth: auth, params: [
                    "start_date": Self.apiDate(interval.start),
                    "end_date": Self.apiDate(interval.end),
                    "start": String(offset),
                    "limit": String(pageSize)
                ])
                let page = SchoologyUpcomingEvent.decodeList(Self.object(data))
                guard !page.isEmpty else { break }

                let newEvents = page.filter { seenIDs.insert($0.id).inserted }
                monthEvents.append(contentsOf: newEvents)
                if page.count < pageSize || newEvents.isEmpty { break }
                offset += pageSize
            }

            calendarMonthEvents = monthEvents.filter { event in
                guard let date = event.date else { return false }
                return date >= interval.start && date < interval.end
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            calendarLoadedMonth = key
        } catch {
            calendarError = error.localizedDescription
        }
    }

    func loadCalendarUpcoming(force: Bool = false) async {
        guard let auth, !isLoadingCalendar else { return }
        if hasLoadedCalendarUpcoming && !force { return }
        isLoadingCalendar = true
        calendarError = nil
        defer { isLoadingCalendar = false }
        do {
            let data = try await api.get("users/\(auth.userID)/events", auth: auth, params: [
                "start_date": Self.apiDate(Date()), "start": "0", "limit": "100"
            ])
            calendarUpcomingEvents = SchoologyUpcomingEvent.decodeList(Self.object(data))
                .filter { ($0.date ?? .distantPast) >= Calendar.current.startOfDay(for: Date()) }
                .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            hasLoadedCalendarUpcoming = true
        } catch {
            calendarError = error.localizedDescription
            hasLoadedCalendarUpcoming = true
        }
    }

    func loadSchoolID(for course: SchoologyCourse) async -> String? {
        if let schoolID = course.schoolID, !schoolID.isEmpty { return schoolID }
        guard let auth,
              let data = try? await api.get("sections/\(course.id)", auth: auth) else { return nil }
        let root = Self.object(data)
        let section = (root["section"] as? [String: Any]) ?? root
        return SchoologyValue.optionalString(section["school_id"] ?? section["schoolId"])
    }

    func loadSchoolName(for course: SchoologyCourse) async -> String {
        if let cached = schoolNames[course.id] { return cached }
        guard let auth else { return "" }

        var schoolID = course.schoolID
        if let sectionData = try? await api.get("sections/\(course.id)", auth: auth) {
            let sectionJSON = Self.object(sectionData)
            let section = (sectionJSON["section"] as? [String: Any]) ?? sectionJSON
            schoolID = SchoologyValue.optionalString(section["school_id"] ?? section["schoolId"]) ?? schoolID
        }

        guard let schoolID, !schoolID.isEmpty,
              let schoolData = try? await api.get("schools/\(schoolID)", auth: auth) else {
            schoolNames[course.id] = ""
            return ""
        }
        let schoolJSON = Self.object(schoolData)
        let school = (schoolJSON["school"] as? [String: Any]) ?? schoolJSON
        let name = SchoologyValue.string(school["title"] ?? school["name"])
        schoolNames[course.id] = name
        return name
    }

    func loadUpcomingEvents(for course: SchoologyCourse) async -> [SchoologyUpcomingEvent] {
        guard let auth,
              let data = try? await api.get("sections/\(course.id)/events", auth: auth, params: [
                "start_date": Self.apiDate(Date()), "start": "0", "limit": "50"
              ]) else { return [] }
        return SchoologyUpcomingEvent.decodeList(Self.object(data))
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    private func hydrateActivityAuthors(auth: SchoologyAuth) async {
        activities = await hydratedActivityAuthors(activities, auth: auth)
    }

    private func hydratedActivityAuthors(_ items: [SchoologyActivity], auth: SchoologyAuth) async -> [SchoologyActivity] {
        let missingIDs = Set(items.filter { $0.authorName.isEmpty || $0.avatarURL == nil }.compactMap(\.authorID))
        let users = await loadMessageUsers(missingIDs, auth: auth)
        var hydrated = items
        for index in hydrated.indices {
            guard let authorID = hydrated[index].authorID else { continue }
            if authorID == auth.userID {
                if hydrated[index].authorName.isEmpty { hydrated[index].authorName = "You" }
                // The current user is intentionally excluded from the batched
                // users/{id} lookup; hydrate their avatar from the signed-in profile.
                if hydrated[index].avatarURL == nil { hydrated[index].avatarURL = user?.pictureURL }
            } else if let profile = users[authorID] {
                if hydrated[index].authorName.isEmpty { hydrated[index].authorName = profile.nameDisplay }
                if hydrated[index].avatarURL == nil { hydrated[index].avatarURL = profile.pictureURL }
            }
        }
        return hydrated
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func object(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }


    func loadWebSessionCookies() async throws -> [SchoologyWebCookie] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        return try await api.webSessionCookies(auth: auth)
    }

    func loadDiscussion(realm: String, realmID: String, discussionID: String) async throws -> SchoologyProfileItem {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("\(realm)/\(realmID)/discussions/\(discussionID)", auth: auth, params: ["with_attachments": "TRUE", "richtext": "1"])
        let json = Self.object(data)
        let raw = (json["discussion"] as? [String: Any]) ?? (json["data"] as? [String: Any]) ?? json
        return SchoologyProfileItem.decodeList(["discussion": raw], keys: ["discussion"]).first ??
            SchoologyProfileItem(id: discussionID, title: "Discussion", body: "", subtitle: "", url: nil, isAdmin: false, kind: "discussion", collectionID: nil)
    }

    func loadEvent(realm: String, realmID: String, eventID: String) async throws -> SchoologyProfileItem {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("\(realm)/\(realmID)/events/\(eventID)", auth: auth, params: ["with_attachments": "TRUE", "richtext": "1"])
        let json = Self.object(data)
        let raw = (json["event"] as? [String: Any]) ?? (json["data"] as? [String: Any]) ?? json
        return SchoologyProfileItem.decodeList(["event": raw], keys: ["event"]).first ??
            SchoologyProfileItem(id: eventID, title: "Event", body: "", subtitle: "", url: nil, isAdmin: false, kind: "event", collectionID: nil)
    }

    func loadUpdateComments(realm: String, realmID: String, updateID: String) async throws -> [SchoologyComment] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("\(realm)/\(realmID)/updates/\(updateID)/comments", auth: auth, params: [
            "start": "0", "limit": "100", "with_attachments": "TRUE", "richtext": "1"
        ])
        var comments = SchoologyComment.decodeList(Self.object(data))
        let missingIDs = Set(comments.filter { $0.authorName.isEmpty || $0.avatarURL == nil }.compactMap(\.authorID))
            .subtracting([auth.userID])
        let users = await loadMessageUsers(missingIDs, auth: auth)
        for index in comments.indices {
            guard let authorID = comments[index].authorID else { continue }
            if authorID == auth.userID {
                if comments[index].authorName.isEmpty { comments[index].authorName = "You" }
                if comments[index].avatarURL == nil { comments[index].avatarURL = user?.pictureURL }
            } else if let profile = users[authorID] {
                if comments[index].authorName.isEmpty { comments[index].authorName = profile.nameDisplay }
                if comments[index].avatarURL == nil { comments[index].avatarURL = profile.pictureURL }
            }
        }
        return SchoologyComment.ordered(comments)
    }

    func postUpdateComment(realm: String, realmID: String, updateID: String, body: String, parentID: String? = nil) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("\(realm)/\(realmID)/updates/\(updateID)/comments", auth: auth, params: [
            "comment": body,
            "parent_id": parentID ?? "0"
        ])
    }

    func loadUpdateLikes(updateID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("like/\(updateID)", auth: auth)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["users", "user", "items", "data"])
    }

    func setUpdateLike(updateID: String, liked: Bool) async throws -> Bool {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.postJSON("like/\(updateID)", auth: auth, body: [
            "like_action": liked
        ])
        let response = Self.object(data)
        if let value = response["user_like_action"] ?? response["userLikeAction"] ?? response["liked"] {
            return SchoologyValue.bool(value)
        }
        return liked
    }

    func loadCommentLikes(updateID: String, commentID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("like/\(updateID)/comment/\(commentID)", auth: auth)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["users", "user", "items", "data"])
    }

    func setCommentLike(updateID: String, commentID: String, liked: Bool) async throws -> Bool {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.postJSON("like/\(updateID)/comment/\(commentID)", auth: auth, body: [
            "like_action": liked
        ])
        let response = Self.object(data)
        if let value = response["user_like_action"] ?? response["userLikeAction"] ?? response["liked"] {
            return SchoologyValue.bool(value)
        }
        return liked
    }

    func loadDiscussionComments(realm: String, realmID: String, discussionID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("\(realm)/\(realmID)/discussions/\(discussionID)/comments", auth: auth, params: ["start": "0", "limit": "100", "with_attachments": "TRUE", "richtext": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["comment", "comments", "items"])
    }

    func loadAssignmentComments(sectionID: String, assignmentID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(sectionID)/assignments/\(assignmentID)/comments", auth: auth, params: ["start": "0", "limit": "100", "with_attachments": "TRUE", "richtext": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["comment", "comments", "items"])
    }

    func loadEventComments(realm: String, realmID: String, eventID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("\(realm)/\(realmID)/events/\(eventID)/comments", auth: auth, params: ["start": "0", "limit": "100", "with_attachments": "TRUE", "richtext": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["comment", "comments", "items"])
    }

    func postComment(realm: String, realmID: String, entity: String, entityID: String, body: String, parentID: String? = nil) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("\(realm)/\(realmID)/\(entity)/\(entityID)/comments", auth: auth, params: [
            "comment": body,
            "parent_id": parentID ?? "0"
        ])
    }

    func loadGroupAlbum(groupID: String, albumID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/albums/\(albumID)", auth: auth, params: ["with_content": "TRUE"])
        let json = Self.object(data)
        let album = (json["album"] as? [String: Any]) ?? json
        return SchoologyProfileItem.decodeList(album["content"] ?? album["contents"] ?? album["media"], keys: ["content", "contents", "media", "photo", "photos", "items"])
    }

    func loadGroupResources(groupID: String, folderID: String? = nil, collectionID: String? = nil) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        var params = ["limit": "50", "with_attachments": "TRUE"]
        if let folderID, !folderID.isEmpty { params["f"] = folderID }
        let path: String
        if let collectionID, !collectionID.isEmpty { path = "collections/\(collectionID)/resources" }
        else { path = "groups/\(groupID)/resources" }
        let data = try await api.get(path, auth: auth, params: params)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["resource", "resources", "collection", "items"])
    }

    func loadPersonProfile(userID: String) async throws -> SchoologyProfileItem {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("users/\(userID)", auth: auth)
        let json = Self.object(data)
        let user = (json["user"] as? [String: Any]) ?? json
        return SchoologyProfileItem.decodeList(["user": user], keys: ["user"]).first ??
            SchoologyProfileItem(id: userID, title: "Schoology user", body: "", subtitle: "", url: nil, isAdmin: false, kind: "person", collectionID: nil)
    }

    func loadPersonUpdates(userID: String) async throws -> [SchoologyActivity] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("users/\(userID)/updates", auth: auth, params: [
            "start": "0", "limit": "20", "with_attachments": "TRUE", "richtext": "1"
        ])
        var updates = await hydratedActivityAuthors(SchoologyActivity.decodeList(Self.object(data)), auth: auth)
        for index in updates.indices {
            if updates[index].authorName.isEmpty {
                updates[index].authorName = user?.id == userID ? (user?.nameDisplay ?? "You") : "Schoology user"
            }
            if updates[index].avatarURL == nil, user?.id == userID { updates[index].avatarURL = user?.pictureURL }
            if updates[index].commentRealm == nil { updates[index].commentRealm = "users" }
            if updates[index].commentRealmID == nil { updates[index].commentRealmID = userID }
        }
        return updates
    }

    func loadPersonBadges(userID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("users/\(userID)/badges", auth: auth)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["badge", "badges", "items"])
    }


    func loadAssignmentContext(sectionID: String, assignmentID: String) async throws -> SchoologyAssignmentContext {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        async let assignmentRequest = api.get("sections/\(sectionID)/assignments/\(assignmentID)", auth: auth, params: ["richtext": "1", "with_attachments": "TRUE"])
        async let sectionRequest = try? await api.get("sections/\(sectionID)", auth: auth)
        async let enrollmentRequest = try? await api.get("sections/\(sectionID)/enrollments", auth: auth, params: ["uid": auth.userID, "enrollment_status": "1"])
        let (assignmentData, sectionData, enrollmentData) = try await (assignmentRequest, sectionRequest, enrollmentRequest)
        let assignmentRoot = Self.object(assignmentData)
        let rawAssignment = (assignmentRoot["assignment"] as? [String: Any]) ?? assignmentRoot
        let sectionRoot = sectionData.map(Self.object) ?? [:]
        let section = (sectionRoot["section"] as? [String: Any]) ?? sectionRoot
        let enrollmentRoot = enrollmentData.map(Self.object) ?? [:]
        let enrollment = SchoologyValue.list(enrollmentRoot, keys: ["enrollment", "enrollments", "items"]).first ?? [:]
        let gradeItemData = try? await api.get("sections/\(sectionID)/grade_items/\(assignmentID)", auth: auth)
        let gradeItemRoot = gradeItemData.map(Self.object) ?? [:]
        let gradeItem = (gradeItemRoot["assignment"] as? [String: Any]) ?? (gradeItemRoot["grade_item"] as? [String: Any]) ?? (gradeItemRoot["gradeItem"] as? [String: Any]) ?? gradeItemRoot
        let gradeItemID = SchoologyValue.string(gradeItem["id"] ?? gradeItem["grade_item_id"] ?? gradeItem["gradeItemId"] ?? rawAssignment["grade_item_id"], fallback: assignmentID)
        let canSubmit = [rawAssignment["allow_dropbox"], rawAssignment["allowDropbox"], rawAssignment["allow_submission"], rawAssignment["allowSubmission"], gradeItem["allow_dropbox"], gradeItem["allowDropbox"], gradeItem["allow_submission"], gradeItem["allowSubmission"]].contains { SchoologyValue.bool($0) }
        let allowComments = [rawAssignment["allow_discussion"], rawAssignment["allowDiscussion"], gradeItem["allow_discussion"], gradeItem["allowDiscussion"]].contains { SchoologyValue.bool($0) }
        let isTeacher = SchoologyValue.bool(enrollment["admin"] ?? section["admin"] ?? rawAssignment["admin"])
        let enrollmentID = SchoologyValue.optionalString(enrollment["id"] ?? enrollment["enrollment_id"])
        var gradeParams = ["assignment_id": gradeItemID]
        if let enrollmentID { gradeParams["enrollment_id"] = enrollmentID }
        let gradeData = try? await api.get("sections/\(sectionID)/grades", auth: auth, params: gradeParams)
        let gradeRoot = gradeData.map(Self.object) ?? [:]
        let grade = SchoologyValue.list(gradeRoot, keys: ["grade", "grades", "items"]).first ?? [:]
        let rawComment = grade["comment"] ?? grade["teacher_comment"] ?? grade["teacherComment"]
        let teacherComment = SchoologyValue.plainText(SchoologyValue.string((rawComment as? [String: Any])?["comment"] ?? (rawComment as? [String: Any])?["body"] ?? rawComment))
        let type = SchoologyValue.string(rawAssignment["assignment_type"] ?? rawAssignment["assignmentType"] ?? rawAssignment["type"]).lowercased()
        let ltiURL = type == "lti_submission" ? SchoologyValue.url(rawAssignment["web_url"] ?? rawAssignment["webUrl"] ?? rawAssignment["launch_url"] ?? rawAssignment["launchUrl"]) : nil
        let attachmentRows = SchoologyValue.list(rawAssignment["attachments"] ?? rawAssignment["attachment"], keys: ["files", "file", "attachments", "items", "links", "link"])
        let attachments = attachmentRows.compactMap { item -> SchoologyAttachment? in
            guard let url = SchoologyValue.url(item["file_download_url"] ?? item["fileDownloadURL"] ?? item["download_path"] ?? item["downloadPath"] ?? item["url"] ?? item["linkURL"] ?? item["href"]) else { return nil }
            return SchoologyAttachment(title: SchoologyValue.string(item["filename"] ?? item["fileName"] ?? item["title"], fallback: url.lastPathComponent), url: url)
        }
        let profile = SchoologyProfileItem.decodeList(["assignment": rawAssignment], keys: ["assignment"]).first ??
            SchoologyProfileItem(id: assignmentID, title: "Assignment", body: "", subtitle: "", url: nil, isAdmin: false, kind: "assignment", collectionID: nil)
        return SchoologyAssignmentContext(assignment: profile, canSubmit: canSubmit, allowComments: allowComments, isTeacher: isTeacher,
            gradeItemID: gradeItemID, enrollmentID: enrollmentID, ltiURL: ltiURL,
            currentGrade: SchoologyValue.string(grade["grade"] ?? grade["calculated_grade"], fallback: "—"),
            maxPoints: SchoologyValue.string(rawAssignment["max_points"] ?? rawAssignment["maxPoints"] ?? gradeItem["max_points"] ?? gradeItem["maxPoints"]),
            teacherComment: teacherComment, attachments: attachments)
    }

    func loadAssignmentSubmissions(sectionID: String, context: SchoologyAssignmentContext) async throws -> SchoologyAssignmentSubmissionSummary {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        func commentText(_ record: [String: Any]) -> String {
            let value = record["comment"] ?? record["teacher_comment"] ?? record["teacherComment"]
            return SchoologyValue.plainText(SchoologyValue.string((value as? [String: Any])?["comment"] ?? (value as? [String: Any])?["body"] ?? value))
        }
        func revisions(from payload: [String: Any]) -> [SchoologyAssignmentRevision] {
            let nested = payload["data"] as? [String: Any]
            let raw = payload["revision"] ?? payload["revisions"] ?? nested?["revision"] ?? nested?["revisions"]
            return SchoologyValue.list(raw, keys: ["revision", "revisions", "items"]).map { row in
                let attachments = SchoologyValue.list(row["attachments"] ?? row["attachment"], keys: ["files", "file", "attachments", "items"]).compactMap { file -> SchoologyAttachment? in
                    guard let url = SchoologyValue.url(file["file_download_url"] ?? file["fileDownloadURL"] ?? file["download_path"] ?? file["downloadPath"] ?? file["url"]) else { return nil }
                    return SchoologyAttachment(title: SchoologyValue.string(file["filename"] ?? file["fileName"] ?? file["title"], fallback: url.lastPathComponent), url: url)
                }
                return SchoologyAssignmentRevision(id: SchoologyValue.string(row["revision_id"] ?? row["revisionId"] ?? row["id"], fallback: "0"),
                    created: SchoologyValue.string(row["created"] ?? row["timestamp"]),
                    body: SchoologyValue.plainText(SchoologyValue.string(row["body"] ?? row["message"])),
                    status: SchoologyValue.bool(row["draft"]) ? "Draft" : (SchoologyValue.bool(row["late"]) ? "Late" : "On time"),
                    attachments: attachments)
            }.sorted { (Int($0.id) ?? 0) > (Int($1.id) ?? 0) }
        }
        if context.isTeacher {
            async let enrollmentsRequest = api.get("sections/\(sectionID)/enrollments", auth: auth, params: ["enrollment_status": "1", "limit": "200"])
            async let gradesRequest = api.get("sections/\(sectionID)/grades", auth: auth, params: ["assignment_id": context.gradeItemID, "limit": "200"])
            async let submissionsRequest = try? await api.get("sections/\(sectionID)/submissions/\(context.gradeItemID)", auth: auth, params: ["with_attachments": "TRUE", "all_revisions": "TRUE", "limit": "200"])
            let (enrollmentData, gradeData, submissionData) = try await (enrollmentsRequest, gradesRequest, submissionsRequest)
            let enrollments = SchoologyValue.list(Self.object(enrollmentData), keys: ["enrollment", "enrollments", "items"]).filter { !SchoologyValue.bool($0["admin"]) && SchoologyValue.string($0["status"], fallback: "1") == "1" }
            let grades = SchoologyValue.list(Self.object(gradeData), keys: ["grade", "grades", "items"])
            let gradeByEnrollment = Dictionary(grades.compactMap { row -> (String, [String: Any])? in
                let id = SchoologyValue.string(row["enrollment_id"] ?? row["enrollmentId"])
                return id.isEmpty ? nil : (id, row)
            }, uniquingKeysWith: { first, _ in first })
            let root = submissionData.map(Self.object) ?? [:]
            let nested = root["data"] as? [String: Any]
            let revisions = SchoologyValue.list(root["revision"] ?? root["revisions"] ?? nested?["revision"] ?? nested?["revisions"], keys: ["revision", "revisions", "items"])
            let students = enrollments.map { row -> SchoologyAssignmentStudent in
                let uid = SchoologyValue.string(row["uid"] ?? row["user_id"] ?? row["userId"])
                let eid = SchoologyValue.string(row["id"] ?? row["enrollment_id"])
                let grade = gradeByEnrollment[eid] ?? [:]
                let revision = revisions.first { SchoologyValue.string($0["uid"] ?? $0["user_id"] ?? $0["userId"]) == uid }
                let status = revision.map { SchoologyValue.bool($0["draft"]) ? "Draft" : (SchoologyValue.bool($0["late"]) ? "Late" : "Submitted") } ?? "Not submitted"
                let display = SchoologyValue.string(row["name_display"] ?? row["display_name"] ?? row["name"])
                let fallback = [SchoologyValue.string(row["name_first"]), SchoologyValue.string(row["name_last"])].filter { !$0.isEmpty }.joined(separator: " ")
                return SchoologyAssignmentStudent(id: uid.isEmpty ? eid : uid, enrollmentID: eid, name: display.isEmpty ? (fallback.isEmpty ? "Student" : fallback) : display,
                    status: status, grade: SchoologyValue.string(grade["grade"] ?? grade["calculated_grade"], fallback: "—"))
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return SchoologyAssignmentSubmissionSummary(grade: "—", teacherComment: "", revisions: [], students: students)
        }
        var gradeParams = ["assignment_id": context.gradeItemID]
        if let enrollmentID = context.enrollmentID { gradeParams["enrollment_id"] = enrollmentID }
        async let gradeRequest = api.get("sections/\(sectionID)/grades", auth: auth, params: gradeParams)
        async let submissionRequest = try? await api.get("sections/\(sectionID)/submissions/\(context.gradeItemID)/\(auth.userID)", auth: auth, params: ["with_attachments": "TRUE", "all_revisions": "TRUE", "start": "0", "limit": "200"])
        let (gradeData, submissionData) = try await (gradeRequest, submissionRequest)
        let grade = SchoologyValue.list(Self.object(gradeData), keys: ["grade", "grades", "items"]).first ?? [:]
        let root = submissionData.map(Self.object) ?? [:]
        return SchoologyAssignmentSubmissionSummary(grade: SchoologyValue.string(grade["grade"] ?? grade["calculated_grade"], fallback: "—"),
            teacherComment: commentText(grade), revisions: revisions(from: root), students: [])
    }

    func submitAssignmentText(sectionID: String, gradeItemID: String, text: String, draft: Bool) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw SchoologyAPIError.invalidResponse }
        _ = try await api.postJSON("sections/\(sectionID)/submissions/\(gradeItemID)/create", auth: auth,
            params: ["realm": "sections", "realm_id": sectionID, "grade_item_id": gradeItemID, "action": "create"],
            body: ["body": value, "draft": draft ? 1 : 0])
    }

    func submitAssignmentFile(data: Data, filename: String, mime: String, sectionID: String, assignmentID: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        try await api.submitAssignmentFile(data: data, filename: filename, mime: mime, sectionID: sectionID, assignmentID: assignmentID, auth: auth)
    }


    func submitAssignmentResource(sectionID: String, assignmentID: String, resourceID: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        guard !sectionID.isEmpty, !assignmentID.isEmpty, !resourceID.isEmpty else { throw SchoologyAPIError.invalidResponse }
        _ = try await api.postJSON("course/\(sectionID)/materials/assignments/\(assignmentID)/dropbox/create_resource_submission",
            auth: auth, body: ["files": [["schoology_resource_id": resourceID]]])
    }

    func loadTeacherAssignmentGrade(sectionID: String, assignmentID: String, enrollmentID: String) async throws -> SchoologyTeacherGrade {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(sectionID)/grades", auth: auth, params: ["assignment_id": assignmentID, "enrollment_id": enrollmentID])
        let row = SchoologyValue.list(Self.object(data), keys: ["grade", "grades", "items"]).first ?? [:]
        let rawComment = row["comment"] ?? row["teacher_comment"] ?? row["teacherComment"]
        let comment = SchoologyValue.plainText(SchoologyValue.string((rawComment as? [String: Any])?["comment"] ?? (rawComment as? [String: Any])?["body"] ?? rawComment))
        return SchoologyTeacherGrade(grade: SchoologyValue.string(row["grade"] ?? row["calculated_grade"]), comment: comment,
            commentVisible: SchoologyValue.bool(row["comment_status"] ?? row["commentStatus"]))
    }

    func loadTeacherAssignmentRevisions(sectionID: String, gradeItemID: String, userID: String) async throws -> [SchoologyAssignmentRevision] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get(
            "sections/\(sectionID)/submissions/\(gradeItemID)/\(userID)",
            auth: auth,
            params: ["with_attachments": "TRUE", "all_revisions": "TRUE", "start": "0", "limit": "200"]
        )
        let root = Self.object(data)
        let nested = root["data"] as? [String: Any]
        let rawRevisions = root["revision"] ?? root["revisions"] ?? nested?["revision"] ?? nested?["revisions"]
        return SchoologyValue.list(rawRevisions, keys: ["revision", "revisions", "items"]).map { row in
            let files = SchoologyValue.list(row["attachments"] ?? row["attachment"], keys: ["files", "file", "attachments", "items"])
            let attachments = files.compactMap { file -> SchoologyAttachment? in
                guard let url = SchoologyValue.url(file["file_download_url"] ?? file["fileDownloadURL"] ?? file["download_path"] ?? file["downloadPath"] ?? file["url"]) else { return nil }
                let converted = SchoologyValue.url(file["file_converted_download_url"] ?? file["fileConvertedDownloadURL"] ?? file["converted_download_path"] ?? file["convertedDownloadPath"])
                return SchoologyAttachment(
                    title: SchoologyValue.string(file["filename"] ?? file["fileName"] ?? file["title"], fallback: url.lastPathComponent),
                    url: url,
                    viewURL: converted
                )
            }
            return SchoologyAssignmentRevision(
                id: SchoologyValue.string(row["revision_id"] ?? row["revisionId"] ?? row["id"], fallback: "0"),
                created: SchoologyValue.string(row["created"] ?? row["timestamp"]),
                body: SchoologyValue.plainText(SchoologyValue.string(row["body"] ?? row["message"])),
                status: SchoologyValue.bool(row["draft"]) ? "Draft" : (SchoologyValue.bool(row["late"]) ? "Late" : "On time"),
                attachments: attachments
            )
        }.sorted { (Int($0.id) ?? 0) > (Int($1.id) ?? 0) }
    }

    func updateTeacherAssignmentGrade(sectionID: String, assignmentID: String, enrollmentID: String, grade: String, comment: String, commentVisible: Bool) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let value = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && Double(value) == nil { throw SchoologyAPIError.invalidResponse }
        guard let enrollment = Int(enrollmentID), enrollment > 0 else { throw SchoologyAPIError.invalidResponse }
        _ = try await api.putJSON("sections/\(sectionID)/grades/\(assignmentID)", auth: auth, body: [
            "enrollment_id": enrollment, "grade": value, "comment": comment, "comment_status": commentVisible ? 1 : 0
        ])
    }

    func searchMessageRecipients(_ query: String) async throws -> [SchoologyMessageRecipient] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("messages/recipients", auth: auth, params: ["name": query, "limit": "10"])
        return SchoologyMessageRecipient.decodeList(data)
    }

    func uploadMessageFile(data: Data, filename: String, mime: String) async throws -> String {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        return try await api.uploadMessageFile(data: data, filename: filename, mime: mime, auth: auth)
    }

    func sendMessage(recipientIDs: [String], subject: String, message: String, fileIDs: [String] = [], resourceIDs: [String] = []) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let ids = Array(Set(recipientIDs.filter { Int($0) != nil })).sorted()
        guard !ids.isEmpty, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SchoologyAPIError.invalidResponse }
        var payload: [String: Any] = [
            "recipient_ids": ids.joined(separator: ","), "subject": subject.trimmingCharacters(in: .whitespacesAndNewlines),
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        let validFileIDs = fileIDs.compactMap(Int.init)
        if !validFileIDs.isEmpty { payload["file-attachment"] = ["id": validFileIDs] }
        let validResourceIDs = resourceIDs.compactMap(Int.init)
        if !validResourceIDs.isEmpty { payload["attachments"] = validResourceIDs.map { ["resource": $0] } }
        _ = try await api.postJSON("messages", auth: auth, body: payload)
    }

    func loadAssignment(sectionID: String, assignmentID: String) async throws -> SchoologyProfileItem {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("sections/\(sectionID)/assignments/\(assignmentID)", auth: auth, params: ["richtext": "1", "with_attachments": "TRUE"])
        let json = Self.object(data)
        let assignment = (json["assignment"] as? [String: Any]) ?? json
        return SchoologyProfileItem.decodeList(["assignment": assignment], keys: ["assignment"]).first ??
            SchoologyProfileItem(id: assignmentID, title: "Assignment", body: "", subtitle: "", url: nil, isAdmin: false, kind: "assignment", collectionID: nil)
    }

    private func loadMessageUsers(_ ids: Set<String>, auth: SchoologyAuth) async -> [String: SchoologyUser] {
        let requestedIDs = ids.filter { !$0.isEmpty && $0 != auth.userID }.sorted()
        guard !requestedIDs.isEmpty else { return [:] }
        let api = self.api
        let responseData = await withTaskGroup(
            of: (String, Data?).self,
            returning: [String: Data].self
        ) { group in
            var responses: [String: Data] = [:]
            var nextIndex = 0
            for id in requestedIDs.prefix(6) {
                group.addTask { (id, try? await api.get("users/\(id)", auth: auth)) }
                nextIndex += 1
            }
            while let (id, data) = await group.next() {
                if let data { responses[id] = data }
                if nextIndex < requestedIDs.count {
                    let nextID = requestedIDs[nextIndex]
                    nextIndex += 1
                    group.addTask { (nextID, try? await api.get("users/\(nextID)", auth: auth)) }
                }
            }
            return responses
        }

        var users: [String: SchoologyUser] = [:]
        for (id, data) in responseData {
            let json = Self.object(data)
            let raw = (json["user"] as? [String: Any]) ?? json
            guard raw["id"] != nil else { continue }
            users[id] = SchoologyUser(
                id: id,
                nameDisplay: SchoologyValue.string(raw["name_display"] ?? raw["display_name"] ?? raw["name"], fallback: "Schoology user"),
                pictureURL: SchoologyValue.url(raw["picture_url"] ?? raw["pictureUrl"] ?? raw["picture"])
            )
        }
        return users
    }

    private func embeddedMessageUsers(_ payload: [String: Any]) -> [String: SchoologyUser] {
        let nested = payload["data"] as? [String: Any]
        let value = payload["user"] ?? payload["users"] ?? nested?["user"] ?? nested?["users"]
        let rows = SchoologyValue.list(value, keys: ["user", "users", "items", "data"])
        var users: [String: SchoologyUser] = [:]
        for raw in rows {
            let id = SchoologyValue.string(raw["id"] ?? raw["user_id"] ?? raw["uid"])
            guard !id.isEmpty else { continue }
            users[id] = SchoologyUser(
                id: id,
                nameDisplay: SchoologyValue.string(raw["name_display"] ?? raw["display_name"] ?? raw["name"], fallback: "Schoology user"),
                pictureURL: SchoologyValue.url(raw["picture_url"] ?? raw["pictureUrl"] ?? raw["picture"])
            )
        }
        return users
    }

    func cachedMessages(for folder: SchoologyMessageFolder) -> [SchoologyMessage] {
        cachedMessagesByFolder[folder.rawValue] ?? []
    }

    func loadMessages(folder: SchoologyMessageFolder, force: Bool = false) async -> [SchoologyMessage] {
        guard let auth else { return [] }
        messageFolder = folder
        if !force, let cached = cachedMessagesByFolder[folder.rawValue] {
            messageErrors[folder.rawValue] = nil
            return cached
        }
        errorMessage = nil
        messageErrors[folder.rawValue] = nil
        let endpoint = folder == .sent ? "messages/sent" : "messages/inbox"
        do {
            let data = try await api.get(endpoint, auth: auth, params: ["limit": "50"])
            let rows = SchoologyMessage.decodeList(Self.object(data))
            var hydrated = rows
            let ids = Set(rows.compactMap { row in
                if folder == .sent { return row.recipientID }
                return row.personName.isEmpty ? row.authorID : nil
            })
            let users = await loadMessageUsers(ids, auth: auth)
            for index in hydrated.indices {
                let id = folder == .sent ? hydrated[index].recipientID : hydrated[index].authorID
                hydrated[index].personName = users[id ?? ""]?.nameDisplay ?? (id == auth.userID ? (user?.nameDisplay ?? "You") : "Schoology")
                hydrated[index].personPictureURL = users[id ?? ""]?.pictureURL
                    ?? (id == auth.userID ? user?.pictureURL : nil)
                    ?? hydrated[index].personPictureURL
            }
            let result = folder == .unread ? hydrated.filter(\.isUnread) : hydrated
            cachedMessagesByFolder[folder.rawValue] = result
            return result
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            messageErrors[folder.rawValue] = message
            return cachedMessagesByFolder[folder.rawValue] ?? []
        }
    }

    func loadMessageThread(_ message: SchoologyMessage, folder: SchoologyMessageFolder) async -> [SchoologyMessage] {
        guard let auth else { return [] }
        let sourceFolder = folder == .sent ? "sent" : "inbox"
        errorMessage = nil
        do {
            let data = try await api.get("messages/\(sourceFolder)/\(message.id)", auth: auth, params: ["with_attachments": "TRUE", "richtext": "1"])
            let json = Self.object(data)
            let payload = (json["data"] as? [String: Any]) ?? (json["response"] as? [String: Any]) ?? json
            let rows = SchoologyMessage.decodeList(json)
            var result = rows
            var users = embeddedMessageUsers(payload)
            let missingIDs = Set(rows.filter { $0.personName.isEmpty }.compactMap(\.authorID))
                .subtracting(users.keys)
                .subtracting([auth.userID])
            let fetchedUsers = await loadMessageUsers(missingIDs, auth: auth)
            users.merge(fetchedUsers) { existing, _ in existing }
            for index in result.indices {
                guard let id = result[index].authorID else { continue }
                if id == auth.userID {
                    result[index].personName = "You"
                    result[index].personPictureURL = user?.pictureURL
                } else if let user = users[id] {
                    result[index].personName = user.nameDisplay
                    result[index].personPictureURL = user.pictureURL
                }
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func loadNotifications(force: Bool = false, markRead: Bool = true) async {
        guard let auth, !isLoadingNotifications else { return }
        if !force && hasLoadedNotifications && !notificationsHasMore { return }
        let start = force ? 0 : notifications.count
        isLoadingNotifications = true
        isLoadingMoreNotifications = !force && start > 0
        if force { notificationsError = nil }
        defer {
            isLoadingNotifications = false
            isLoadingMoreNotifications = false
        }
        do {
            let data = try await api.get("notifications", auth: auth, params: ["start": String(start), "limit": "50"])
            let page = SchoologyNotificationPage.decode(data, start: start, limit: 50)
            if force {
                notifications = page.notifications
            } else {
                var knownIDs = Set(notifications.map(\.id))
                notifications.append(contentsOf: page.notifications.filter { knownIDs.insert($0.id).inserted })
            }
            notificationsHasMore = page.hasMore
            notificationsError = nil
            hasLoadedNotifications = true
            // Android marks the collection read after the first response reports unread items.
            if markRead && start == 0 && page.unviewedCount > 0 {
                _ = try? await api.post("notifications/read", auth: auth)
            }
        } catch {
            notificationsError = error.localizedDescription
            hasLoadedNotifications = true
        }
    }


    func createGroupUpdate(groupID: String, body: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("groups/\(groupID)/updates", auth: auth, params: ["body": body])
    }

    private func createPostDate(_ date: Date, allDay: Bool, endOfDay: Bool = false) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone.current
        formatter.dateFormat = allDay ? (endOfDay ? "yyyy-MM-dd '23:59:00'" : "yyyy-MM-dd '00:00:00'") : "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    func createHomeDiscussion(destination: SchoologyHomeCreateDestination, title: String, body: String, published: Bool, dueDate: Date?, graded: Bool, maxPoints: Double?, factor: Double, fileIDs: [String] = [], resourceIDs: [String] = []) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        guard destination.canCreateDiscussion, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SchoologyAPIError.invalidResponse }
        var payload: [String: Any] = ["title": title.trimmingCharacters(in: .whitespacesAndNewlines), "body": body, "published": published ? 1 : 0]
        if let dueDate { payload["due_date"] = createPostDate(dueDate, allDay: false) }
        if graded { guard let maxPoints, maxPoints > 0, factor > 0 else { throw SchoologyAPIError.invalidResponse }; payload["graded"] = 1; payload["max_points"] = maxPoints; payload["factor"] = factor }
        let files = fileIDs.compactMap(Int.init); if !files.isEmpty { payload["file-attachment"] = ["id": files] }
        let resources = resourceIDs.compactMap(Int.init); if !resources.isEmpty { payload["attachments"] = resources.map { ["resource": $0] } }
        _ = try await api.postJSON("\(destination.realm)/\(destination.resourceID)/discussions", auth: auth, body: payload)
    }

    func createHomeEvent(destination: SchoologyHomeCreateDestination, title: String, description: String, start: Date, allDay: Bool, end: Date?, rsvp: Int, commentsEnabled: Bool, fileIDs: [String] = [], resourceIDs: [String] = []) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        guard destination.canCreateEvent, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, end.map({ $0 >= start }) ?? true else { throw SchoologyAPIError.invalidResponse }
        var payload: [String: Any] = ["title": title.trimmingCharacters(in: .whitespacesAndNewlines), "description": description, "start": createPostDate(start, allDay: allDay), "is_all_day": allDay ? 1 : 0, "rsvp": rsvp, "comments_enabled": commentsEnabled ? 1 : 0]
        if let end { payload["has_end"] = 1; payload["end"] = createPostDate(end, allDay: allDay, endOfDay: allDay) }
        let files = fileIDs.compactMap(Int.init); if !files.isEmpty { payload["file-attachment"] = ["id": files] }
        let resources = resourceIDs.compactMap(Int.init); if !resources.isEmpty { payload["attachments"] = resources.map { ["resource": $0] } }
        _ = try await api.postJSON("\(destination.realm)/\(destination.resourceID)/events", auth: auth, body: payload)
    }

    func createGroupDiscussion(groupID: String, title: String, body: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("groups/\(groupID)/discussions", auth: auth, params: [
            "title": title, "body": body, "published": "1"
        ])
    }

    func createGroupEvent(groupID: String, title: String, description: String, start: Date, allDay: Bool) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = allDay ? "yyyy-MM-dd '00:00:00'" : "yyyy-MM-dd HH:mm:ss"
        _ = try await api.post("groups/\(groupID)/events", auth: auth, params: [
            "title": title, "description": description, "start": formatter.string(from: start),
            "is_all_day": allDay ? "1" : "0", "rsvp": "0", "comments_enabled": "1"
        ])
    }

    func createGroupAlbum(groupID: String, title: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("groups/\(groupID)/albums", auth: auth, params: ["title": title])
    }

    func addGroupResource(groupID: String, resourceID: String) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        _ = try await api.post("groups/\(groupID)/resources", auth: auth, params: ["resource": resourceID])
    }

    func loadGroupProfile(_ group: SchoologyGroup) async throws -> SchoologyGroupProfile {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(group.id)", auth: auth)
        let raw = Self.object(data)
        let row = (raw["group"] as? [String: Any]) ?? raw
        let paths = ["updates", "discussions", "events", "albums", "resources"].map { "/v1/groups/\(group.id)/\($0)" }
        let permissionsData = try? await api.postMultiOptions(paths, auth: auth)
        return SchoologyGroupProfile(
            group: SchoologyGroup(
                id: SchoologyValue.string(row["id"] ?? row["group_id"], fallback: group.id),
                title: SchoologyValue.string(row["title"] ?? row["name"], fallback: group.title),
                schoolID: SchoologyValue.optionalString(row["school_id"] ?? row["schoolId"]) ?? group.schoolID,
                pictureURL: SchoologyValue.url(row["picture_url"] ?? row["pictureUrl"]) ?? group.pictureURL
            ),
            permissions: SchoologyGroupPermissions.decode(permissionsData.map(Self.object) ?? [:], groupID: group.id),
            members: [], updates: [], upcoming: [], discussions: [], albums: [], resources: []
        )
    }

    func loadGroupUpdates(groupID: String) async throws -> [SchoologyActivity] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/updates", auth: auth,
            params: ["start": "0", "limit": "20", "with_attachments": "TRUE", "richtext": "1"])
        var rows = SchoologyActivity.decodeList(Self.object(data))
        for index in rows.indices {
            rows[index].commentRealm = "groups"
            rows[index].commentRealmID = groupID
        }
        return await hydratedActivityAuthors(rows, auth: auth)
    }

    func loadGroupMembers(groupID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/enrollments", auth: auth,
            params: ["start": "0", "limit": "200", "enrollment_status": "1"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["enrollment", "enrollments", "member", "members", "user", "users"])
    }

    func loadGroupUpcoming(groupID: String) async throws -> [SchoologyUpcomingEvent] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/events", auth: auth,
            params: ["start": Self.apiDate(Date()), "limit": "20"])
        return SchoologyUpcomingEvent.decodeList(Self.object(data))
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    func loadGroupDiscussions(groupID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/discussions", auth: auth, params: ["limit": "50"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["discussion", "discussions"])
    }

    func loadGroupAlbums(groupID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/albums", auth: auth, params: ["limit": "50"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["album", "albums"])
    }

    func loadGroupResources(groupID: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data = try await api.get("groups/\(groupID)/resources", auth: auth,
            params: ["limit": "50", "with_attachments": "TRUE"])
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["resource", "resources", "collection", "items"])
    }

    func loadSchoolName(for group: SchoologyGroup) async -> String {
        if let cached = schoolNames[group.id] { return cached }
        guard let auth, let schoolID = group.schoolID, !schoolID.isEmpty,
              let data = try? await api.get("schools/\(schoolID)", auth: auth) else { return "" }
        let raw = Self.object(data)
        let school = (raw["school"] as? [String: Any]) ?? raw
        let name = SchoologyValue.string(school["title"] ?? school["name"])
        schoolNames[group.id] = name
        return name
    }

    func loadSchoolResources(schoolID: String, folderID: String? = nil, collectionID: String? = nil) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        var params = ["start": "0", "limit": "200", "with_attachments": "TRUE"]
        if let folderID, !folderID.isEmpty, folderID != "0" { params["f"] = folderID }
        let path: String
        if let collectionID, !collectionID.isEmpty {
            path = "collections/\(collectionID)/resources"
        } else {
            path = "schools/\(schoolID)/resources"
        }
        let data = try await api.get(path, auth: auth, params: params)
        return SchoologyProfileItem.decodeList(Self.object(data), keys: ["resource", "resources", "resource_list", "items"])
    }

    func loadCoursePermissions(courseID: String) async -> SchoologyCoursePermissions? {
        guard let auth else { return nil }
        let paths = ["/v1/sections/\(courseID)/documents", "/v1/sections/\(courseID)/updates"]
        guard let data = try? await api.postMultiOptions(paths, auth: auth) else { return nil }
        let root = Self.object(data)
        let rows = (root["response"] as? [[String: Any]]) ?? (root["responses"] as? [[String: Any]]) ?? []
        var bodies: [String: String] = [:]
        for row in rows {
            guard let location = row["location"] as? String else { continue }
            let body = row["body"] ?? ""
            bodies[location] = (body as? String ?? String(describing: body)).lowercased()
        }
        func allowsPost(_ path: String) -> Bool {
            bodies[path]?.range(of: #"\bpost\b"#, options: .regularExpression) != nil
        }
        return SchoologyCoursePermissions(
            canPostUpdates: allowsPost("/v1/sections/\(courseID)/updates"),
            canAddResources: allowsPost("/v1/sections/\(courseID)/documents")
        )
    }

    func loadPostableUpdateDestinations() async -> [SchoologyUpdateDestination] {
        guard let auth else { return [] }
        let destinations =
            courses.map { SchoologyUpdateDestination(realm: "sections", resourceID: $0.id, title: $0.title) } +
            groups.map { SchoologyUpdateDestination(realm: "groups", resourceID: $0.id, title: $0.title) }
        guard !destinations.isEmpty else { return [] }
        let paths = destinations.map { "/v1/\($0.realm)/\($0.resourceID)/updates" }
        guard let data = try? await api.postMultiOptions(paths, auth: auth) else { return [] }
        let root = Self.object(data)
        let rows = (root["response"] as? [[String: Any]]) ?? (root["responses"] as? [[String: Any]]) ?? []
        var bodies: [String: String] = [:]
        for row in rows {
            guard let location = row["location"] as? String else { continue }
            let body = row["body"] ?? ""
            bodies[location] = (body as? String ?? String(describing: body)).lowercased()
        }
        return destinations.filter { destination in
            bodies["/v1/\(destination.realm)/\(destination.resourceID)/updates"]?
                .range(of: #"\bpost\b"#, options: .regularExpression) != nil
        }
    }

    func loadHomeCreateDestinations() async -> [SchoologyHomeCreateDestination] {
        guard let auth else { return [] }
        let destinations = [SchoologyHomeCreateDestination(realm: "users", resourceID: auth.userID, title: "My Account", canCreateDiscussion: false, canCreateEvent: false)] +
            courses.map { SchoologyHomeCreateDestination(realm: "sections", resourceID: $0.id, title: $0.title, canCreateDiscussion: false, canCreateEvent: false) } +
            groups.map { SchoologyHomeCreateDestination(realm: "groups", resourceID: $0.id, title: $0.title, canCreateDiscussion: false, canCreateEvent: false) }
        let paths = destinations.flatMap { ["/v1/\($0.realm)/\($0.resourceID)/discussions", "/v1/\($0.realm)/\($0.resourceID)/events"] }
        guard let data = try? await api.postMultiOptions(paths, auth: auth) else { return [] }
        let root = Self.object(data)
        let rows = (root["response"] as? [[String: Any]]) ?? (root["responses"] as? [[String: Any]]) ?? []
        var bodies: [String: String] = [:]
        for row in rows { if let location = row["location"] as? String { bodies[location] = String(describing: row["body"] ?? "").lowercased() } }
        return destinations.map { destination in
            let base = "/v1/\(destination.realm)/\(destination.resourceID)/"
            func canPost(_ suffix: String) -> Bool { bodies[base + suffix]?.range(of: #"\bpost\b"#, options: .regularExpression) != nil }
            return SchoologyHomeCreateDestination(realm: destination.realm, resourceID: destination.resourceID, title: destination.title,
                canCreateDiscussion: canPost("discussions"), canCreateEvent: canPost("events"))
        }.filter { $0.canCreateDiscussion || $0.canCreateEvent }
    }

    func postUpdate(destination: SchoologyUpdateDestination, body: String, fileIDs: [String] = [], resourceIDs: [String] = []) async throws {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SchoologyAPIError.invalidResponse }
        var payload: [String: Any] = ["body": text]
        let validFileIDs = fileIDs.compactMap(Int.init)
        if !validFileIDs.isEmpty { payload["file-attachment"] = ["id": validFileIDs] }
        let validResourceIDs = resourceIDs.compactMap(Int.init)
        if !validResourceIDs.isEmpty { payload["attachments"] = validResourceIDs.map { ["resource": $0] } }
        _ = try await api.postJSON("\(destination.realm)/\(destination.resourceID)/updates", auth: auth, body: payload)
    }

    func loadSchoolProfile(_ id: String) async throws -> SchoologySchoolProfile {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        async let detail = api.get("schools/\(id)", auth: auth)
        async let updatesRequest = try? await api.get("schools/\(id)/updates", auth: auth, params: ["start": "0", "limit": "50", "with_attachments": "TRUE", "richtext": "1"])
        async let eventsRequest = try? await api.get("schools/\(id)/events", auth: auth, params: ["start": Self.apiDate(Date()), "limit": "50"])
        async let resourcesRequest = try? await api.get("schools/\(id)/resources", auth: auth, params: ["start": "0", "limit": "200", "with_attachments": "TRUE"])
        let d = try await detail
        let (u, e, r) = await (updatesRequest, eventsRequest, resourcesRequest)
        let raw = Self.object(d)
        let school = (raw["school"] as? [String: Any]) ?? raw
        var updates = SchoologyActivity.decodeList(Self.object(u ?? Data()))
        for index in updates.indices {
            updates[index].commentRealm = "schools"
            updates[index].commentRealmID = id
        }
        updates = await hydratedActivityAuthors(updates, auth: auth)
        return SchoologySchoolProfile(
            school: SchoologyProfileSchool(
                id: id,
                title: SchoologyValue.string(school["title"] ?? school["name"], fallback: "School"),
                pictureURL: SchoologyValue.url(school["picture_url"] ?? school["pictureUrl"] ?? school["picture"] ?? school["image"]),
                address: ["address1", "address2", "city", "state", "postal_code", "country"]
                    .compactMap { school[$0] as? String }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", "),
                phone: SchoologyValue.string(school["phone"])
            ),
            updates: updates,
            upcoming: SchoologyUpcomingEvent.decodeList(Self.object(e ?? Data())),
            resources: SchoologyProfileItem.decodeList(Self.object(r ?? Data()), keys: ["resource", "resources", "resource_list"])
        )
    }

    func loadSchoolDiscussions(_ id: String) async throws -> [SchoologyProfileItem] {
        guard let auth else { throw SchoologyAPIError.notSignedIn }
        let data=try await api.get("schools/\(id)/discussions",auth:auth,params:["start":"0","limit":"50","with_attachments":"TRUE","richtext":"1"])
        return SchoologyProfileItem.decodeList(Self.object(data),keys:["discussion","discussions"])
    }

    private func refreshPeopleDirectoryAvailability(auth: SchoologyAuth) async {
        async let userData = try? api.get("users/\(auth.userID)", auth: auth)
        async let mobileData = try? api.get("mobile/me", auth: auth)
        let (userResponse, mobileResponse) = await (userData, mobileData)
        let userRoot = Self.object(userResponse ?? Data())
        let user = (userRoot["user"] as? [String: Any]) ?? userRoot
        let mobileRoot = Self.object(mobileResponse ?? Data())
        let mobile = (mobileRoot["user"] as? [String: Any]) ?? (mobileRoot["mobile_me"] as? [String: Any]) ?? mobileRoot
        func truthy(_ value: Any?) -> Bool { SchoologyValue.bool(value) }
        let enterprise = [
            user["is_enterprise_user"], user["isEnterpriseUser"], user["enterprise"],
            user["is_enterprise"], user["isEnterprise"], user["enterprise_enabled"],
            mobile["is_enterprise_user"], mobile["isEnterpriseUser"], mobile["enterprise"],
            mobile["is_enterprise"], mobile["isEnterprise"], mobile["enterprise_enabled"]
        ].contains(where: truthy) || [
            user["ent_stat"], user["entStat"], user["ENT_STAT"],
            mobile["ent_stat"], mobile["entStat"], mobile["ENT_STAT"]
        ].contains { SchoologyValue.string($0) == "573" }
        let directoryPublic = [
            user["is_directory_public"], user["directory_public"],
            user["isDirectoryPublic"], user["directoryPublic"]
        ].contains(where: truthy)
        peopleDirectoryEnabled = enterprise && directoryPublic
    }

    func signOut() {
        KeychainStore.clear()
        auth = nil
        user = nil
        peopleDirectoryEnabled = false
        courses = []
        groups = []
        notifications = []
        cachedMessagesByFolder = [:]
        messageErrors = [:]
        hasLoadedNotifications = false
        isLoadingNotifications = false
        isLoadingMoreNotifications = false
        notificationsHasMore = true
        notificationsError = nil
        resourceCollections = []
        resourceApps = []
        hasLoadedResources = false
        resourcesError = nil
        userGradeCourses = []
        hasLoadedUserGrades = false
        userGradesError = nil
        calendarMonthEvents = []
        calendarUpcomingEvents = []
        calendarLoadedMonth = ""
        hasLoadedCalendarUpcoming = false
        calendarError = nil
        activities = []
        upcomingEvents = []
        hasLoadedHomeActivities = false
        hasLoadedHomeCourses = false
        hasLoadedHomeUpcoming = false
        homeActivitiesError = nil
        homeCoursesError = nil
        homeUpcomingError = nil
        schoolNames = [:]
        destination = .home
        homeSection = .recent
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
