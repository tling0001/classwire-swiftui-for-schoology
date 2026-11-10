import SwiftUI

struct ClassWireAIAssistantView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = ClassWireAIAssistantStore()
    @State private var draft = ""
    @State private var historySearch = ""
    @State private var showingSettings = false
    @State private var showingHistory = false
    @FocusState private var composerFocused: Bool
    @State private var availableModels: [String] = []
    @State private var isRefreshingModels = false
    @State private var modelDiscoveryStatus = ""

    private var filteredConversations: [ClassWireAIConversation] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.conversations }
        return store.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.messages.contains { $0.content.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if geometry.size.width >= 760 {
                    conversationSidebar
                        .frame(width: min(max(geometry.size.width * 0.25, 220), 300))
                    Divider()
                }
                chatColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            if !showingSettings {
                ClassWirePuterWebView(webView: ClassWirePuterService.shared.webView)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .navigationTitle("ClassWire AI")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("New conversation", systemImage: "square.and.pencil", action: store.createConversation)
                #if os(iOS)
                Button("Conversation history", systemImage: "clock") { showingHistory = true }
                #endif
                Button("AI settings", systemImage: "gearshape") { showingSettings = true }
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task { await refreshAvailableModels() }
        }) {
            ClassWireAISettingsView(store: store)
        }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                historyList
                    .navigationTitle("Conversations")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingHistory = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .environment(\.openURL, OpenURLAction { url in
            handleCitation(url)
        })
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: store.activeConversationID)
    }

    private var conversationSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Label("History", systemImage: "clock")
                    .font(.headline)
                Spacer()
                Button("New", systemImage: "plus", action: store.createConversation)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("New conversation")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            TextField("Search conversations", text: $historySearch)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if filteredConversations.isEmpty {
                ContentUnavailableView.search(text: historySearch)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredConversations) { conversation in
                        conversationButton(conversation)
                            .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .listRowBackground(
                                conversation.id == store.activeConversationID
                                ? SchoologyStyle.blue.opacity(0.12)
                                : Color.clear
                            )
                            .contextMenu {
                                Button("Delete conversation", systemImage: "trash", role: .destructive) {
                                    store.deleteConversation(conversation.id)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(.regularMaterial)
    }

    private var historyList: some View {
        List {
            ForEach(filteredConversations) { conversation in
                conversationButton(conversation)
            }
            .onDelete { offsets in
                let ids = offsets.map { filteredConversations[$0].id }
                for id in ids { store.deleteConversation(id) }
            }
        }
        .searchable(text: $historySearch, prompt: "Search conversations")
        .overlay {
            if filteredConversations.isEmpty {
                ContentUnavailableView.search(text: historySearch)
            }
        }
    }

    private func conversationButton(_ conversation: ClassWireAIConversation) -> some View {
        Button {
            store.selectConversation(conversation.id)
            showingHistory = false
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(conversation.id == store.activeConversationID ? .isSelected : [])
    }

    private var chatColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(SchoologyStyle.blue)
                    .frame(width: 38, height: 38)
                    .background(SchoologyStyle.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClassWire AI").font(.headline)
                    Text(store.provider.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isSending {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    messageTimelineContent
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: store.activeConversation?.messages.count ?? 0) { _, _ in
                    guard let last = store.activeConversation?.messages.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded {
                    if composerFocused { composerFocused = false }
                })
            }

            Divider()
            composer
        }
        .background(.background)
        .task { await refreshAvailableModels() }
        .onChange(of: store.provider) { _, _ in Task { await refreshAvailableModels() } }
        .onChange(of: store.ollamaEndpoint) { _, _ in Task { await refreshAvailableModels() } }
        .onChange(of: store.hasSavedProviderKey) { _, _ in Task { await refreshAvailableModels() } }
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Schoology copilot")
                    .font(.largeTitle.bold())
                Text("Ask about courses, assignments, grades, materials, upcoming work, and messages. ClassWire AI uses your signed-in Schoology account to look up relevant information.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if store.provider.requiresAPIKey && !store.hasSavedProviderKey {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Finish AI setup", systemImage: "key.fill")
                        .font(.headline)
                    Text("Add your \(store.provider.title) API key in settings. Your key is stored in the device Keychain. Your prompts and the Schoology information needed to answer them are sent to the AI provider you choose.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open AI settings", systemImage: "gearshape") { showingSettings = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            if session.isTeacher {
                VStack(spacing: 8) {
                    promptButton("Plan a lesson", subtitle: "Build a lesson from course materials", prompt: "Help me create a lesson outline using the materials in my current course. Include learning objectives, activities, and a short assessment.", symbol: "book.closed")
                    promptButton("Review class activity", subtitle: "Summarize recent course updates", prompt: "Summarize recent updates and upcoming work across my courses.", symbol: "chart.bar.xaxis")
                    promptButton("Draft an announcement", subtitle: "Write an update for students", prompt: "Draft a concise course announcement about upcoming work. Do not publish it.", symbol: "megaphone")
                    promptButton("Find key materials", subtitle: "Locate resources for the next lesson", prompt: "Find and summarize the most relevant materials in my current course for the next lesson.", symbol: "folder")
                    promptButton("Prepare a study guide", subtitle: "Create review topics for students", prompt: "Create a student-friendly study guide using the learning materials in my current course.", symbol: "list.clipboard")
                }
            } else {
                VStack(spacing: 8) {
                    promptButton("Plan my week", subtitle: "What assignments are due soon?", prompt: "What assignments are due soon?", symbol: "calendar")
                    promptButton("Understand an assignment", subtitle: "Explain the assignment I am viewing", prompt: "Explain the assignment I am viewing", symbol: "doc.text")
                    promptButton("Review my grades", subtitle: "Check my course progress", prompt: "Show my grades for my courses", symbol: "chart.bar")
                    promptButton("Find course materials", subtitle: "Locate a resource I need", prompt: "Find the materials in my current course that are relevant to my upcoming assignments.", symbol: "books.vertical")
                    promptButton("Make a study guide", subtitle: "Prepare for an upcoming test", prompt: "Help me make a study guide using my course materials and upcoming assignments.", symbol: "graduationcap")
                }
            }

            Label("You stay in control. Changes always require your confirmation.", systemImage: "checkmark.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 620, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func promptButton(_ title: String, subtitle: String, prompt: String, symbol: String) -> some View {
        Button {
            Task { await store.send(prompt, session: session) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(SchoologyStyle.blue)
                    .frame(width: 38, height: 38)
                    .background(SchoologyStyle.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isSending)
        .frame(minHeight: 44)
    }

    private func messageBubble(_ message: ClassWireAIMessage) -> some View {
        let isUser = message.role == "user"
        return HStack(alignment: .top, spacing: 8) {
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SchoologyStyle.blue)
                    .frame(width: 28, height: 28)
                    .background(SchoologyStyle.blue.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: 36)
            }

            Text(attributedMessage(message.content))
                .textSelection(.enabled)
                .font(.body)
                .padding(12)
                .frame(maxWidth: 680, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    isUser ? SchoologyStyle.blue.opacity(0.12) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16)
                )

            if !isUser {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var conversationMessages: some View {
        if let conversation = store.activeConversation, conversation.messages.isEmpty {
            welcomeContent
        } else {
            ForEach(store.activeConversation?.messages ?? []) { message in
                messageBubble(message)
                    .id(message.id)
            }
        }
    }

    @ViewBuilder
    private var pendingActionContent: some View {
        if let action = store.pendingAction {
            actionProposal(action)
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let error = store.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if !store.status.isEmpty {
            Text(store.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Status: \(store.status)")
        }
    }

    private var messageTimelineContent: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            conversationMessages
            pendingActionContent
            errorContent
            statusContent
        }
        .padding(16)
        .frame(maxWidth: 900, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var composer: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            composerContent
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        } else {
            composerContent
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
    }

    private var composerContent: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about your Schoology work…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .focused($composerFocused)
                    .onSubmit(sendDraft)
                    .accessibilityLabel("Message ClassWire AI")

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(SchoologyStyle.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(store.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends your question to ClassWire AI.")
            }

            HStack(spacing: 8) {
                Menu {
                    Button("Refresh models", systemImage: "arrow.clockwise") {
                        Task { await refreshAvailableModels() }
                    }
                    if !availableModels.isEmpty { Divider() }
                    ForEach(availableModels, id: \.self) { model in
                        Button {
                            store.model = model
                            store.persistSettings()
                            composerFocused = false
                        } label: {
                            if store.model == model {
                                Label(model, systemImage: "checkmark")
                            } else {
                                Text(model)
                            }
                        }
                    }
                } label: {
                    Label(store.model, systemImage: "cpu")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Choose AI model")
                .accessibilityHint("Selects a model available from the current provider.")

                if isRefreshingModels {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing available models")
                } else if !modelDiscoveryStatus.isEmpty {
                    Text(modelDiscoveryStatus)
                        .font(.caption)
                        .foregroundStyle(
                            modelDiscoveryStatus.localizedCaseInsensitiveContains("failed") ||
                            modelDiscoveryStatus.localizedCaseInsensitiveContains("could not") ||
                            modelDiscoveryStatus.localizedCaseInsensitiveContains("timed out")
                            ? .red : .secondary
                        )
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func refreshAvailableModels() async {
        guard !isRefreshingModels else { return }
        let selectedProvider = store.provider
        let selectedEndpoint = store.ollamaEndpoint
        let selectedKey = ClassWireAIKeychainStore.load(provider: selectedProvider) ?? ""
        if selectedProvider == .puter {
            let puterService = ClassWirePuterService.shared
            isRefreshingModels = true
            modelDiscoveryStatus = "Checking Puter connection…"
            defer { isRefreshingModels = false }
            do {
                await puterService.refreshAuthStatus()
                guard puterService.isSignedIn else {
                    availableModels = [store.model]
                    modelDiscoveryStatus = "Connect your Puter account in AI settings"
                    return
                }
                modelDiscoveryStatus = "Loading Puter models…"
                let models = try await puterService.listModels()
                guard store.provider == selectedProvider else { return }
                let discovered = Array(Set(models)).sorted()
                availableModels = discovered.isEmpty ? [store.model] : discovered
                if !discovered.isEmpty && !discovered.contains(store.model), let first = discovered.first {
                    store.model = first
                    store.persistSettings()
                }
                modelDiscoveryStatus = models.isEmpty ? "No models returned" : "\(models.count) available"
            } catch {
                availableModels = [store.model]
                modelDiscoveryStatus = "Puter refresh failed: \(error.localizedDescription)"
            }
            return
        }
        guard selectedProvider == .ollama || !selectedKey.isEmpty else {
            availableModels = [store.model]
            modelDiscoveryStatus = "Add an API key to load models"
            return
        }

        isRefreshingModels = true
        modelDiscoveryStatus = "Loading models…"
        defer { isRefreshingModels = false }

        do {
            var request: URLRequest
            switch selectedProvider {
            case .gemini:
                request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!)
                request.setValue(selectedKey, forHTTPHeaderField: "x-goog-api-key")
            case .openai:
                request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                request.setValue("Bearer \(selectedKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=100")!)
                request.setValue(selectedKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            case .puter:
                throw ClassWireAIError.unsupportedProvider
            case .ollama:
                let base = selectedEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard let baseURL = URL(string: base), ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""), baseURL.host != nil else {
                    throw ClassWireAIError.invalidResponse("Enter a valid Ollama server URL in AI settings.")
                }
                request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
            }

            request.httpMethod = "GET"
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw ClassWireAIError.invalidResponse("Model discovery failed (HTTP \(status)).")
            }
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let models: [String]
            switch selectedProvider {
            case .gemini:
                models = (root["models"] as? [[String: Any]] ?? []).compactMap { item in
                    let methods = item["supportedGenerationMethods"] as? [String] ?? []
                    guard methods.contains("generateContent") else { return nil }
                    return (item["name"] as? String)?.replacingOccurrences(of: "models/", with: "")
                }
            case .openai:
                models = (root["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }.filter {
                    let id = $0.lowercased()
                    return (id.hasPrefix("gpt-") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4"))
                        && !["audio", "realtime", "transcribe", "tts", "embedding", "moderation"].contains(where: id.contains)
                }
            case .anthropic:
                models = (root["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }.filter { $0.hasPrefix("claude-") }
            case .ollama:
                models = (root["models"] as? [[String: Any]] ?? []).compactMap { ($0["name"] as? String) ?? ($0["model"] as? String) }
            case .puter:
                models = []
            }
            guard store.provider == selectedProvider, store.ollamaEndpoint == selectedEndpoint else { return }
            availableModels = Array(Set(models)).sorted()
            if !availableModels.contains(store.model) { availableModels.insert(store.model, at: 0) }
            modelDiscoveryStatus = models.isEmpty ? "No models returned; current model retained" : "\(models.count) available"
        } catch {
            guard store.provider == selectedProvider else { return }
            availableModels = [store.model]
            modelDiscoveryStatus = error.localizedDescription
        }
    }

    private func actionProposal(_ action: ClassWireAIPendingAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Review before changing Schoology", systemImage: "hand.raised.fill")
                .font(.headline)
            Text(action.title).font(.subheadline.weight(.semibold))
            Text(action.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            if action.type == "send_message" {
                Text("To: \(action.values["recipient_name"] ?? "")")
                    .font(.subheadline)
                Text("Subject: \(action.values["subject"] ?? "")")
                    .font(.subheadline)
                Text(action.values["message"] ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
            } else if action.type == "submit_assignment_text" {
                Text(attributedMessage(action.values["preview_markdown"] ?? action.values["text"] ?? ""))
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
            } else if action.type == "post_course_update" {
                Text(action.values["body"] ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
            } else if action.type == "update_assignment_grade" {
                LabeledContent("Proposed grade", value: action.values["grade"] ?? "")
                if let comment = action.values["comment"], !comment.isEmpty {
                    Text(comment)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack {
                Button("Cancel", role: .cancel, action: store.cancelPendingAction)
                    .buttonStyle(.bordered)
                    .disabled(store.isSending)
                Spacer()
                Button("Confirm", systemImage: "checkmark") {
                    Task { await store.confirmPendingAction(session: session) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSending)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func sendDraft() {
        let value = draft
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = ""
        composerFocused = false
        Task { await store.send(value, session: session) }
    }

    private func attributedMessage(_ raw: String) -> AttributedString {
        let pattern = #"\[\[(course|group|assignment):(\d+)(?::(\d+))?\|([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        }
        let source = raw as NSString
        var converted = raw
        for match in regex.matches(in: raw, range: NSRange(location: 0, length: source.length)).reversed() {
            guard match.numberOfRanges >= 5,
                  let kindRange = Range(match.range(at: 1), in: raw),
                  let idRange = Range(match.range(at: 2), in: raw),
                  let titleRange = Range(match.range(at: 4), in: raw),
                  let fullRange = Range(match.range, in: converted) else { continue }
            let kind = String(raw[kindRange])
            let id = String(raw[idRange])
            let title = String(raw[titleRange])
            var components = URLComponents()
            components.scheme = "classwire-ai"
            components.host = kind
            components.path = "/\(id)"
            var queryItems = [URLQueryItem(name: "title", value: title)]
            if kind == "assignment", match.range(at: 3).location != NSNotFound,
               let sectionRange = Range(match.range(at: 3), in: raw) {
                queryItems.append(URLQueryItem(name: "section", value: String(raw[sectionRange])))
            }
            components.queryItems = queryItems
            if let url = components.url {
                converted.replaceSubrange(fullRange, with: "[\(title)](\(url.absoluteString))")
            }
        }
        return (try? AttributedString(markdown: converted)) ?? AttributedString(converted)
    }

    private func handleCitation(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "classwire-ai", let kind = url.host else { return .systemAction }
        let id = url.pathComponents.last ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let sectionID = components?.queryItems?.first(where: { $0.name == "section" })?.value
        let title = components?.queryItems?.first(where: { $0.name == "title" })?.value ?? kind.capitalized
        session.pendingAINavigation = ClassWireAINavigationRequest(
            kind: kind, id: id, sectionID: sectionID, title: title
        )
        return .handled
    }
}
