import SwiftUI

struct SignInView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @FocusState private var focusedField: CredentialField?

    @State private var mode: Mode = .welcome
    @State private var searchText = ""
    @State private var schools: [SchoologySchool] = []
    @State private var selectedSchool: SchoologySchool?
    @State private var username = ""
    @State private var password = ""
    @State private var canadian = false
    @State private var searching = false
    @State private var showingDemoConfirmation = false

    private enum Mode {
        case welcome, school, credentials, schoolBrowser, qr
    }

    private enum CredentialField: Hashable {
        case username, password
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .school: schoolPicker
                case .credentials: credentials
                case .welcome, .schoolBrowser, .qr:
                    ScrollView {
                        VStack(spacing: 22) {
                            switch mode {
                            case .welcome: welcome
                            case .schoolBrowser: schoolBrowserProgress
                            case .qr: qrLogin
                            case .school, .credentials: EmptyView()
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 28)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 560)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .tint(LoginPalette.blue)
        .onAppear { canadian = session.canadianServer }
        .alert("Unable to sign in", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: modeKey)
    }

    private var modeKey: Int {
        switch mode {
        case .welcome: 0
        case .school: 1
        case .credentials: 2
        case .schoolBrowser: 3
        case .qr: 4
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            ClassWireBrandLockup()
                .padding(.top, 30)
                .padding(.bottom, 34)

            VStack(spacing: 14) {
                LoginActionButton(title: "Sign in through my school", icon: .school, style: .primary) {
                    session.errorMessage = nil
                    mode = .school
                }
                LoginActionButton(title: "Sign in with my account", icon: .account, style: .outlined) {
                    session.errorMessage = nil
                    selectedSchool = nil
                    mode = .credentials
                }
                LoginActionButton(title: "Sign in with a QR code", icon: .qr, style: .outlined) {
                    session.errorMessage = nil
                    mode = .qr
                }
            }
            .frame(maxWidth: 420)
            .padding(.top, 22)

            Button("I need help signing in") {
                if let url = URL(string: "https://docs.powerschool.com/SGYH/en/students/schoology-mobile-apps/logging-into-the-schoology-mobile-app-students") {
                    openURL(url)
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
            .padding(.top, 30)

            instanceSwitch
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
    }

    private var schoolPicker: some View {
        Form {
            Section { subpageHeader }
            Section("School") {
                TextField("School", text: $searchText, prompt: Text("Enter your school or domain"))
                    .textContentType(.organizationName)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    #endif
                    .autocorrectionDisabled()
                    .onSubmit { Task { await searchSchools(searchText) } }
                    .onChange(of: searchText) { _, value in
                        Task { await searchSchools(value) }
                    }
                if searching {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Searching schools…").foregroundStyle(.secondary)
                    }
                } else if !searchText.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle") {
                        searchText = ""
                        schools = []
                    }
                }
            }
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
               schools.isEmpty, !searching {
                Section {
                    ContentUnavailableView.search(text: searchText).frame(minHeight: 150)
                }
            }
            if !schools.isEmpty {
                Section("Results") {
                    ForEach(schools) { school in
                        Button {
                            selectedSchool = school
                            session.errorMessage = nil
                            if school.loginType?.caseInsensitiveCompare("oauth") == .orderedSame {
                                mode = .schoolBrowser
                                Task { await signInThroughSchool() }
                            } else {
                                // Non-OAuth schools use the same native account
                                // credential form as "Sign in with my account".
                                mode = .credentials
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "building.2")
                                    .font(.title3)
                                    .foregroundStyle(LoginPalette.blue)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(school.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                    if !school.domain.isEmpty {
                                        Text(school.domain).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityHint("Starts sign-in with this school.")
                    }
                }
            }
            Section { instanceSwitch }
        }
        .formStyle(.grouped)
        // Keep Form's native grouped background, matching Settings and system dialogs.
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var credentials: some View {
        Form {
            Section {
                subpageHeader
                Text(selectedSchool?.title ?? "Sign in with my account")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("Account") {
                TextField("Username or Email", text: $username, prompt: Text("Enter your username or email"))
                    .textContentType(.username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                SecureField("Password", text: $password, prompt: Text("Enter your password"))
                    .textContentType(.password)
                    #if os(iOS)
                    .submitLabel(.go)
                    #endif
                    .focused($focusedField, equals: .password)
                    .onSubmit { signIn() }
                Button {
                    signIn()
                } label: {
                    HStack(spacing: 9) {
                        if session.isLoading { ProgressView() }
                        Text(session.isLoading ? "Signing in…" : "Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || session.isLoading)
            }
            Section {
                instanceSwitch
                Button("I need help signing in") {
                    if let url = URL(string: "https://docs.powerschool.com/SGYH/en/students/schoology-mobile-apps/logging-into-the-schoology-mobile-app-students") {
                        openURL(url)
                    }
                }
                .font(.footnote)
            }
        }
        .formStyle(.grouped)
        // Keep Form's native grouped background, matching Settings and system dialogs.
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .onAppear {
            if selectedSchool == nil { focusedField = .username }
        }
        .alert("Welcome to the ClassWire demo", isPresented: $showingDemoConfirmation) {
            Button("Enter Demo") { session.beginDemoMode() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You are entering ClassWire’s interactive demo with fictional sample data. It covers the main learning and communication workflows; some Schoology-backed actions and external tools are simulated or unavailable. Changes stay local and are not sent to Schoology, submitted as coursework, or delivered as messages.")
        }
    }

    private var schoolBrowserProgress: some View {
        VStack(spacing: 24) {
            subpageHeader

            if let selectedSchool {
                Text(selectedSchool.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            }

            if session.isLoading {
                ProgressView()
                    .controlSize(.large)
                Text("Continue signing in in your browser…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ContentUnavailableView(
                    "School sign-in didn’t complete",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("You can try signing in again.")
                )

                Button("Try browser sign-in again") {
                    Task { await signInThroughSchool() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var qrLogin: some View {
        VStack(spacing: 16) {
            subpageHeader

            Text("QR Code Login")
                .font(.title2.weight(.semibold))

            if session.isLoading {
                ProgressView("Signing in to ClassWire…")
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                Text("Scan Your Code")
                    .font(.headline)

                QRCodeScannerView { value in
                    Task { await session.signInWithQRCode(value) }
                }
                .frame(maxWidth: 390)
                .frame(height: 300)

                Text("Point your camera at the sign-in QR code provided by your school.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var subpageHeader: some View {
        HStack(spacing: 12) {
            Button(action: goBack) {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Back")

            Spacer()
            ClassWireBrandLockup(compact: true)
            Spacer()

            Color.clear.frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 420)
        .padding(.bottom, 8)
    }

    private var instanceSwitch: some View {
        Button(canadian ? "Switch to U.S. sign-in server" : "Switch to Canadian sign-in server") {
            canadian.toggle()
            session.canadianServer = canadian
            session.errorMessage = nil
            Task { await SchoologyAPI.shared.setCanadianServer(canadian) }
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
        }
        .font(.footnote)
        .buttonStyle(.borderless)
    }

    private func goBack() {
        focusedField = nil
        switch mode {
        case .welcome:
            break
        case .school:
            mode = .welcome
        case .credentials:
            mode = .welcome
        case .schoolBrowser:
            session.cancelSchoolSignIn()
            mode = .school
        case .qr:
            mode = .welcome
        }
    }

    private func signInThroughSchool() async {
        guard let domain = selectedSchool?.domain, !domain.isEmpty else {
            session.errorMessage = "This school did not provide a valid login domain."
            return
        }
        await session.signInThroughSchool(domain: domain, canadian: canadian)
    }

    private func signIn() {
        focusedField = nil
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if selectedSchool == nil && normalizedUsername == "tester@classwire.app" {
            guard password == "ClassWireDemo2026!" else {
                session.errorMessage = "The ClassWire demo password is incorrect."
                return
            }
            session.errorMessage = nil
            showingDemoConfirmation = true
            return
        }
        Task {
            await session.signIn(
                username: username,
                password: password,
                schoolID: selectedSchool?.id,
                canadian: canadian
            )
        }
    }

    private func searchSchools(_ query: String) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            schools = []
            return
        }
        searching = true
        defer { searching = false }
        do {
            await SchoologyAPI.shared.setCanadianServer(canadian)
            var results = try await SchoologyAPI.shared.searchSchools(query)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("app.classwire.com") == .orderedSame,
               !results.contains(where: { $0.domain.caseInsensitiveCompare("app.classwire.com") == .orderedSame }),
               let testSchool = SchoologySchool(json: [
                   "id": "classwire-test",
                   "title": "ClassWire Test School",
                   "domain": "app.classwire.com",
                   "login_type": "oauth"
               ]) {
                results.append(testSchool)
            }
            schools = results
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

private enum LoginPalette {
    static let blue = SchoologyStyle.blue
}

private struct ClassWireBrandLockup: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            ClassWireMark(size: compact ? 27 : 38)
            HStack(spacing: 0) {
                Text("Class").foregroundStyle(.primary)
                Text("Wire").foregroundStyle(Color(red: 72.0 / 255, green: 175.0 / 255, blue: 236.0 / 255))
            }
            .font(.system(size: compact ? 23 : 34, weight: .light, design: .default))
            .tracking(compact ? -0.7 : -1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ClassWire")
    }
}

private struct ClassWireMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(red: 72.0 / 255, green: 175.0 / 255, blue: 236.0 / 255),
                    lineWidth: size * 0.083
                )
                .padding(size * 0.0415)
            ClassWireGlyph()
                .fill(.primary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ClassWireGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.midX + (x - 10 + 0.9) * rect.width / 20 * 0.70,
                y: rect.midY + (y - 10) * rect.height / 20 * 0.70
            )
        }

        var path = Path()
        path.move(to: point(15.7, 4.6))
        path.addCurve(to: point(9.8, 2), control1: point(13.5, 2.9), control2: point(11.8, 2))
        path.addCurve(to: point(2, 10), control1: point(5, 2), control2: point(2, 5.3))
        path.addCurve(to: point(9.8, 18), control1: point(2, 14.7), control2: point(5, 18))
        path.addCurve(to: point(15.7, 15.4), control1: point(11.8, 18), control2: point(13.5, 17.1))
        path.addLine(to: point(13.5, 13.2))
        path.addCurve(to: point(9.8, 14.8), control1: point(12.5, 14.5), control2: point(11.2, 14.8))
        path.addCurve(to: point(5.1, 10), control1: point(6.8, 14.8), control2: point(5.1, 12.8))
        path.addCurve(to: point(9.8, 5.2), control1: point(5.1, 7.2), control2: point(6.8, 5.2))
        path.addCurve(to: point(13.5, 6.8), control1: point(11.2, 5.2), control2: point(12.5, 5.5))
        path.closeSubpath()
        return path
    }
}

private struct LoginActionButton: View {
    enum Icon {
        case school, account, qr
    }

    enum Style: Equatable {
        case primary, outlined
    }

    let title: String
    let icon: Icon
    let style: Style
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, macOS 26, *) {
                if style == .primary {
                    Button(action: action) { buttonLabel }
                        .buttonStyle(.glassProminent)
                } else {
                    Button(action: action) { buttonLabel }
                        .buttonStyle(.glass)
                }
            } else if style == .primary {
                Button(action: action) { buttonLabel }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) { buttonLabel }
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .tint(LoginPalette.blue)
        .accessibilityLabel(title)
    }

    private var buttonLabel: some View {
        HStack(spacing: 12) {
            Group {
                switch icon {
                case .school:
                    Image(systemName: "building.2")
                case .account:
                    ClassWireMark(size: 27)
                case .qr:
                    Image(systemName: "qrcode")
                }
            }
            .font(.title3)
            .frame(width: 30, height: 30)
            Text(title).font(.body.weight(.semibold))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
