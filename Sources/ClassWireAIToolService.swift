import Foundation

@MainActor
enum ClassWireAIToolExecution {
    case data(Any)
    case action(ClassWireAIPendingAction)
}

@MainActor
enum ClassWireAIToolService {
    static let definitions: [[String: Any]] = [
        tool("get_courses", "List signed-in Schoology courses."),
        tool("get_groups", "List signed-in Schoology groups."),
        tool("get_upcoming_events", "List upcoming Schoology events and assignment due dates.", [
            "days": ["type": "integer", "description": "Number of days to look ahead, from 1 to 120."]
        ]),
        tool("search_assignments", "Search assignment titles and descriptions across courses.", [
            "query": ["type": "string"],
            "course_id": ["type": "integer"]
        ], required: ["query"]),
        tool("get_course_grades", "Get course grade items, grading periods, and the signed-in student's grades.", [
            "course_id": ["type": "integer"]
        ]),
        tool("get_course_materials", "List materials in a course folder.", [
            "course_id": ["type": "integer"],
            "folder_id": ["type": "integer"]
        ]),
        tool("get_course_updates", "List recent updates in a course.", [
            "course_id": ["type": "integer"]
        ]),
        tool("search_messages", "Search recent Schoology inbox and sent messages by subject or body. Returns sender/recipient IDs, timestamps, unread state, and attachment metadata where available.", [
            "query": ["type": "string"],
            "folder": ["type": "string", "enum": ["inbox", "sent", "both"]],
            "limit": ["type": "integer"]
        ], required: ["query"]),
        tool("get_message_thread", "Retrieve Schoology message details by ID from inbox, sent, or both folders.", [
            "message_id": ["type": "integer"],
            "folder": ["type": "string", "enum": ["inbox", "sent", "both"]]
        ], required: ["message_id"]),
        tool("get_current_assignment", "Get the full details for the assignment currently open in ClassWire."),
        tool("get_assignment_submission", "Get a student's assignment submission and revision history. submission_id is the Schoology submission ID, not the assignment ID.", [
            "section_id": ["type": "integer"],
            "submission_id": ["type": "integer"],
            "user_id": ["type": "integer"]
        ], required: ["section_id", "submission_id"]),
        tool("get_current_page", "Get current ClassWire page context and the currently selected course or assignment."),
        tool("navigate_to_schoology_item", "Navigate to a course, group, assignment, or Messages. Navigation only.", [
            "kind": ["type": "string", "enum": ["course", "group", "assignment", "messages"]],
            "id": ["type": "integer"],
            "section_id": ["type": "integer"],
            "title": ["type": "string"]
        ], required: ["kind"]),
        tool("submit_assignment_text", "PROPOSE a rich-text assignment submission. Write the response in Markdown, including paragraphs, headings, bold, italic, inline code, links, and ordered or unordered lists where useful. The user must review and explicitly confirm before it is submitted.", [
            "markdown": ["type": "string", "description": "The complete assignment response formatted as Markdown."],
            "text": ["type": "string", "description": "Plain-text compatibility fallback."],
            "assignment_id": ["type": "integer"],
            "section_id": ["type": "integer"]
        ], required: ["markdown"]),
        tool("create_ai_file", "Create a real text-based file attachment from content you generated. Supported formats are .txt, .md, .csv, and .json. The app keeps the generated file attached to this conversation so it can be submitted to a Schoology assignment after the user reviews and confirms.", [
            "filename": ["type": "string", "description": "Filename ending in .txt, .md, .csv, or .json."],
            "content": ["type": "string", "description": "Complete file contents."]
        ], required: ["filename", "content"]),
        tool("submit_assignment_files", "PROPOSE uploading one or more files already attached in this AI conversation (including AI-generated images or documents) to a Schoology assignment submission. Only use filenames that appear in the attached-file list. This action never runs until the user reviews and explicitly confirms it.", [
            "filenames": ["type": "array", "items": ["type": "string"], "description": "Exact filenames from attached files or AI-generated files. Omit to include all files attached in this conversation."],
            "assignment_id": ["type": "integer", "description": "Schoology assignment ID."],
            "section_id": ["type": "integer", "description": "Schoology course section ID."]
        ], required: ["assignment_id", "section_id"]),
        tool("send_message", "PROPOSE a Schoology message. Write the message body in Markdown, including paragraphs, headings, bold, italic, links, and lists where useful. The app converts the reviewed Markdown to safe Schoology rich-text HTML. The user must review and explicitly confirm before it is sent.", [
            "recipient_name": ["type": "string"],
            "subject": ["type": "string"],
            "message": ["type": "string"]
        ], required: ["recipient_name", "subject", "message"]),
        tool("post_course_update", "PROPOSE a course update. Write the body in Markdown, including paragraphs, headings, bold, italic, links, and lists where useful. The app converts the reviewed Markdown to safe Schoology rich-text HTML. The user must review and explicitly confirm before it is posted.", [
            "body": ["type": "string"],
            "course_id": ["type": "integer"]
        ], required: ["body"]),
        tool("update_assignment_grade", "PROPOSE a teacher grade change. Requires section_id, grade_item_id, and enrollment_id from a teacher grading context. The user must confirm before it is saved.", [
            "grade": ["type": "string"],
            "comment": ["type": "string"],
            "comment_status": ["type": "boolean"],
            "section_id": ["type": "integer"],
            "grade_item_id": ["type": "integer"],
            "enrollment_id": ["type": "integer"]
        ], required: ["grade", "section_id", "grade_item_id", "enrollment_id"])
    ]

    private static func tool(
        _ name: String,
        _ description: String,
        _ properties: [String: Any] = [:],
        required: [String] = []
    ) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "parameters": [
                "type": "object",
                "properties": properties,
                "required": required
            ]
        ]
    }

    private static func api(_ path: String, session: AppSession, params: [String: String] = [:]) async throws -> [String: Any] {
        guard let auth = session.auth else { throw SchoologyAPIError.notSignedIn }
        await SchoologyAPI.shared.setCanadianServer(session.canadianServer)
        let data = try await SchoologyAPI.shared.get(path, auth: auth, params: params)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    private static func rows(_ root: [String: Any], _ keys: String...) -> [[String: Any]] {
        for source in [root, root["data"] as? [String: Any] ?? [:], root["response"] as? [String: Any] ?? [:]] {
            for key in keys {
                if let list = source[key] as? [[String: Any]] { return list }
                if let items = (source[key] as? [String: Any])?["items"] as? [[String: Any]] { return items }
            }
        }
        return []
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? String { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func text(_ value: Any?, fallback: String = "") -> String {
        guard let value, !(value is NSNull) else { return fallback }
        return String(describing: value)
    }

    private static func courseRows(_ session: AppSession) async throws -> [[String: Any]] {
        if !session.courses.isEmpty {
            return session.courses.map { ["id": $0.id, "title": $0.title, "course_title": $0.title] }
        }
        let root = try await api("users/\(session.auth?.userID ?? "")/sections", session: session, params: ["start": "0", "limit": "200"])
        return rows(root, "section", "sections")
    }

    static func run(name: String, arguments: [String: Any], session: AppSession) async throws -> ClassWireAIToolExecution {
        guard let auth = session.auth else { throw SchoologyAPIError.notSignedIn }
        let courseID = text(arguments["course_id"], fallback: session.aiCurrentCourseID ?? "")
        switch name {
        case "get_current_page":
            var context: [String: Any] = [
                "page": session.destination.rawValue,
                "title": session.aiCurrentAssignmentTitle ?? session.aiCurrentCourseTitle ?? session.destination.rawValue
            ]
            if let courseID = session.aiCurrentCourseID {
                context["course"] = ["id": courseID, "title": session.aiCurrentCourseTitle ?? "Current course"]
            }
            if let assignmentID = session.aiCurrentAssignmentID {
                context["assignment"] = [
                    "sectionId": session.aiCurrentCourseID ?? "",
                    "assignmentId": assignmentID,
                    "title": session.aiCurrentAssignmentTitle ?? "Current assignment"
                ]
            }
            return .data(context)

        case "get_courses":
            let availableCourses = try await courseRows(session)
            return .data(availableCourses.map { row in
                let id = text(row["id"] ?? row["section_id"])
                let title = text(row["course_title"] ?? row["courseTitle"] ?? row["title"] ?? row["section_title"], fallback: "Course")
                return ["id": id, "title": title, "citation": "[[course:\(id)|\(title)]]"]
            })

        case "get_groups":
            if !session.groups.isEmpty {
                return .data(session.groups.map { ["id": $0.id, "name": $0.title, "citation": "[[group:\($0.id)|\($0.title)]]"] })
            }
            let root = try await api("users/\(auth.userID)/groups", session: session, params: ["start": "0", "limit": "100"])
            return .data(rows(root, "group", "groups").map { row in
                let id = text(row["id"] ?? row["group_id"])
                let title = text(row["name"] ?? row["title"], fallback: "Group")
                return ["id": id, "name": title, "description": text(row["description"]), "citation": "[[group:\(id)|\(title)]]"]
            })

        case "get_upcoming_events":
            let days = max(1, min(120, number(arguments["days"]) ?? 30))
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd"
            let root = try await api("users/\(auth.userID)/events", session: session, params: [
                "start_date": formatter.string(from: .now), "start": "0", "limit": "100"
            ])
            let cutoff = Date.now.addingTimeInterval(Double(days) * 86_400)
            let events = rows(root, "event", "events").filter { row in
                let raw = text(row["start"] ?? row["due"] ?? row["end"])
                guard let date = ISO8601DateFormatter().date(from: raw) ?? ISO8601DateFormatter().date(from: raw + "T00:00:00Z") else { return true }
                return date <= cutoff
            }
            return .data(events.map { row in
                [
                    "id": text(row["id"]),
                    "title": text(row["title"], fallback: "Event"),
                    "type": text(row["type"]),
                    "due": text(row["start"] ?? row["due"] ?? row["end"]),
                    "sectionId": text(row["section_id"] ?? row["sectionId"]),
                    "assignmentId": text(row["assignment_id"] ?? row["assignmentId"]),
                    "description": text(row["description"])
                ]
            })

        case "search_assignments":
            let query = text(arguments["query"]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { throw ClassWireAIError.action("Enter a word or phrase to search assignments.") }
            let courses = try await courseRows(session)
            let selected = courseID.isEmpty ? courses : courses.filter { text($0["id"] ?? $0["section_id"]) == courseID }
            var matches: [[String: Any]] = []
            for course in selected.prefix(35) {
                let sectionID = text(course["id"] ?? course["section_id"])
                guard !sectionID.isEmpty else { continue }
                do {
                    let root = try await api("sections/\(sectionID)/assignments", session: session, params: ["start": "0", "limit": "200"])
                    for item in rows(root, "assignment", "assignments") {
                        let title = text(item["title"] ?? item["name"], fallback: "Assignment")
                        let description = text(item["description"])
                        guard (title + " " + description).lowercased().contains(query) else { continue }
                        let id = text(item["id"] ?? item["assignment_id"])
                        matches.append([
                            "id": id, "title": title, "due": text(item["due"] ?? item["due_date"]),
                            "course": text(course["course_title"] ?? course["title"], fallback: "Course"),
                            "sectionId": sectionID, "description": description,
                            "citation": "[[assignment:\(id):\(sectionID)|\(title)]]"
                        ])
                    }
                } catch { continue }
            }
            return .data(Array(matches.prefix(50)))

        case "get_course_grades":
            guard !courseID.isEmpty else { throw ClassWireAIError.action("Open a course or supply course_id to inspect grades.") }
            let section = try await api("sections/\(courseID)", session: session)
            let periods = try await api("sections/\(courseID)/grading_periods", session: session)
            let categories = try await api("sections/\(courseID)/grading_categories", session: session)
            let items = try await api("sections/\(courseID)/grade_items", session: session, params: ["limit": "500"])
            let grades = try await api("users/\(auth.userID)/grades", session: session, params: ["section_id": courseID])
            return .data([
                "course": section["section"] ?? section,
                "gradingPeriods": rows(periods, "grading_period", "grading_periods"),
                "gradingCategories": rows(categories, "grading_category", "grading_categories"),
                "gradeItems": rows(items, "assignment", "assignments"),
                "grades": rows(grades, "section", "sections")
            ])

        case "get_course_materials":
            guard !courseID.isEmpty else { throw ClassWireAIError.action("Open a course or supply course_id to inspect materials.") }
            let folderID = text(arguments["folder_id"], fallback: "0")
            let root = try await api("courses/\(courseID)/folder/\(folderID)", session: session)
            return .data(rows(root, "folder-item", "folder_item", "folderItems", "items"))

        case "get_course_updates":
            guard !courseID.isEmpty else { throw ClassWireAIError.action("Open a course or supply course_id to inspect updates.") }
            let root = try await api("sections/\(courseID)/updates", session: session, params: [
                "start": "0", "limit": "50", "with_attachments": "TRUE", "richtext": "1"
            ])
            return .data(rows(root, "update", "updates", "update_list"))

        case "search_messages":
            let query = text(arguments["query"]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { throw ClassWireAIError.action("Enter a word or phrase to search messages.") }
            let folder = text(arguments["folder"], fallback: "both")
            let folders = folder == "both" ? ["inbox", "sent"] : [folder == "sent" ? "sent" : "inbox"]
            var found: [String: [String: Any]] = [:]
            for selectedFolder in folders {
                let endpoint = selectedFolder == "sent" ? "messages/sent" : "messages/inbox"
                let root = try await api(endpoint, session: session, params: ["start": "0", "limit": "100", "with_attachments": "TRUE"])
                for message in rows(root, "message", "messages", "items") {
                    let searchable = [
                        text(message["subject"]), text(message["message"]), text(message["body"]),
                        text(message["author_name"]), text((message["author"] as? [String: Any])?["name"])
                    ].joined(separator: " ").lowercased()
                    guard searchable.contains(query) else { continue }
                    let id = text(message["id"] ?? message["message_id"])
                    found[id + ":" + selectedFolder] = [
                        "id": id, "folder": selectedFolder,
                        "subject": text(message["subject"], fallback: "(No subject)"),
                        "body": text(message["message"] ?? message["body"]),
                        "authorId": text(message["author_id"] ?? message["authorId"]),
                        "recipientIds": text(message["recipient_ids"] ?? message["recipientIds"]),
                        "updated": text(message["last_updated"] ?? message["created"]),
                        "status": text(message["message_status"] ?? message["messageStatus"]),
                        "attachments": message["attachments"] ?? message["attachment"] ?? message["links"] ?? []
                    ]
                }
            }
            return .data(Array(Array(found.values).sorted { text($0["updated"]) > text($1["updated"]) }.prefix(max(1, min(60, number(arguments["limit"]) ?? 30)))))

        case "get_message_thread":
            guard let id = number(arguments["message_id"]), id > 0 else {
                throw ClassWireAIError.action("A valid Schoology message ID is required.")
            }
            let folder = text(arguments["folder"], fallback: "both")
            let folders = folder == "both" ? ["inbox", "sent"] : [folder == "sent" ? "sent" : "inbox"]
            var results: [[String: Any]] = []
            for selectedFolder in folders {
                let root = try await api("messages/\(selectedFolder)/\(id)", session: session, params: [
                    "with_attachments": "TRUE", "richtext": "1"
                ])
                let payload = (root["message"] as? [String: Any]).map { [$0] } ?? rows(root, "message", "messages", "items")
                if !payload.isEmpty { results.append(["folder": selectedFolder, "messages": payload]) }
            }
            guard !results.isEmpty else { throw ClassWireAIError.action("Schoology returned no details for message \(id).") }
            return .data(["requestedMessageId": id, "folders": folders, "results": results])

        case "get_current_assignment":
            guard let sectionID = session.aiCurrentCourseID, let assignmentID = session.aiCurrentAssignmentID else {
                throw ClassWireAIError.action("No assignment is currently open. Open an assignment first.")
            }
            let root = try await api("sections/\(sectionID)/assignments/\(assignmentID)", session: session, params: [
                "richtext": "1", "with_attachments": "TRUE"
            ])
            return .data(root["assignment"] ?? root)

        case "get_assignment_submission":
            guard let sectionID = number(arguments["section_id"]),
                  let submissionID = number(arguments["submission_id"]) else {
                throw ClassWireAIError.action("Valid section_id and submission_id values are required.")
            }
            let userID = number(arguments["user_id"]) ?? Int(auth.userID) ?? 0
            guard userID > 0 else { throw ClassWireAIError.action("A valid user ID is required.") }
            let root = try await api("sections/\(sectionID)/submissions/\(submissionID)/\(userID)", session: session, params: [
                "all_revisions": "TRUE", "with_annotations": "TRUE", "with_attachments": "TRUE"
            ])
            return .data([
                "sectionId": sectionID, "submissionId": submissionID, "userId": userID,
                "revisions": rows(root, "revision", "revisions", "submission"),
                "submission": root["revisions"] ?? root["revision"] ?? root,
                "attachments": root["attachments"] ?? root["files"] ?? []
            ])

        case "navigate_to_schoology_item":
            let kind = text(arguments["kind"])
            if kind == "messages" {
                session.pendingAINavigation = ClassWireAINavigationRequest(kind: "messages", id: "", sectionID: nil, title: "Messages")
            } else {
                let id = text(arguments["id"])
                let sectionID = text(arguments["section_id"])
                let title = text(arguments["title"], fallback: kind.capitalized)
                guard !id.isEmpty else { throw ClassWireAIError.action("Schoology item ID is required for navigation.") }
                if kind == "assignment" && sectionID.isEmpty {
                    throw ClassWireAIError.action("An assignment navigation request must include section_id.")
                }
                session.pendingAINavigation = ClassWireAINavigationRequest(kind: kind, id: id, sectionID: sectionID.isEmpty ? nil : sectionID, title: title)
            }
            return .data(["navigated": true])

        case "submit_assignment_text":
            let markdown = text(arguments["markdown"], fallback: text(arguments["text"])).trimmingCharacters(in: .whitespacesAndNewlines)
            let textValue = ClassWireAIMarkdownHTML.encode(markdown)
            let assignmentID = text(arguments["assignment_id"], fallback: session.aiCurrentAssignmentID ?? "")
            let sectionID = text(arguments["section_id"], fallback: session.aiCurrentCourseID ?? "")
            guard !markdown.isEmpty, !textValue.isEmpty, !assignmentID.isEmpty, !sectionID.isEmpty else {
                throw ClassWireAIError.action("Open an assignment or include section_id and assignment_id with the proposed text.")
            }
            return .action(ClassWireAIPendingAction(
                type: name,
                values: ["text": textValue, "preview_markdown": markdown, "assignment_id": assignmentID, "section_id": sectionID],
                title: "Submit assignment text",
                summary: "Submit the proposed text to \(session.aiCurrentAssignmentTitle ?? "the selected assignment") in \(session.aiCurrentCourseTitle ?? "the selected course")."
            ))

        case "send_message":
            let recipient = text(arguments["recipient_name"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = text(arguments["subject"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let messageMarkdown = text(arguments["message"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let messageHTML = ClassWireAIMarkdownHTML.encode(messageMarkdown)
            guard !recipient.isEmpty, !subject.isEmpty, !messageMarkdown.isEmpty, !messageHTML.isEmpty else {
                throw ClassWireAIError.action("Recipient, subject, and message are required.")
            }
            return .action(ClassWireAIPendingAction(
                type: name,
                values: ["recipient_name": recipient, "subject": subject, "message": messageHTML, "preview_markdown": messageMarkdown],
                title: "Send Schoology message",
                summary: "Send “\(subject)” to \(recipient). Review the full message before confirming."
            ))

        case "post_course_update":
            let bodyMarkdown = text(arguments["body"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyHTML = ClassWireAIMarkdownHTML.encode(bodyMarkdown)
            let targetCourseID = text(arguments["course_id"], fallback: session.aiCurrentCourseID ?? "")
            guard !bodyMarkdown.isEmpty, !bodyHTML.isEmpty, !targetCourseID.isEmpty else {
                throw ClassWireAIError.action("Open a course or include course_id before proposing an update.")
            }
            return .action(ClassWireAIPendingAction(
                type: name,
                values: ["body": bodyHTML, "preview_markdown": bodyMarkdown, "course_id": targetCourseID],
                title: "Post course update",
                summary: "Post this update to \(session.aiCurrentCourseTitle ?? "the selected course"). Review the text before confirming."
            ))

        case "update_assignment_grade":
            let sectionID = text(arguments["section_id"])
            let gradeItemID = text(arguments["grade_item_id"])
            let enrollmentID = text(arguments["enrollment_id"])
            let grade = text(arguments["grade"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sectionID.isEmpty, !gradeItemID.isEmpty, !enrollmentID.isEmpty, !grade.isEmpty else {
                throw ClassWireAIError.action("A teacher grading context with section_id, grade_item_id, and enrollment_id is required.")
            }
            let values = [
                "section_id": sectionID, "grade_item_id": gradeItemID,
                "enrollment_id": enrollmentID, "grade": grade,
                "comment": text(arguments["comment"]),
                "comment_status": (arguments["comment_status"] as? Bool ?? false) ? "true" : "false"
            ]
            return .action(ClassWireAIPendingAction(
                type: name,
                values: values,
                title: "Update assignment grade",
                summary: "Change the selected student's grade to \(grade). Review the grade and comment before confirming."
            ))

        default:
            throw ClassWireAIError.action("Tool unavailable: \(name)")
        }
    }
}
