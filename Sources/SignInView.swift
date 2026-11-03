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
                case .welcome:
                    welcome
                        .transition(.opacity)
                case .school:
                    schoolPicker
                        .transition(.opacity)
                case .credentials:
                    credentials
                        .transition(.opacity)
                case .schoolBrowser:
                    schoolBrowserProgress
                        .transition(.opacity)
                case .qr:
                    qrLogin
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LoginPalette.background.ignoresSafeArea())
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: modeKey)
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
            SchoologyBrandLockup()
                .padding(.top, 42)
                .padding(.bottom, 34)

            Spacer(minLength: 18)

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
                LoginActionButton(title: "Sign in with a QR code", icon: .qr, style: .qr) {
                    session.errorMessage = nil
                    mode = .qr
                }
            }
            .frame(maxWidth: 420)

            Spacer(minLength: 24)

            Button("I need help signing in") {
                if let url = URL(string: "https://docs.powerschool.com/SGYH/en/students/schoology-mobile-apps/logging-into-the-schoology-mobile-app-students") {
                    openURL(url)
                }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.92))
            .buttonStyle(.plain)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var schoolPicker: some View {
        VStack(spacing: 18) {
            subpageHeader

            VStack(alignment: .leading, spacing: 9) {
                Text("School")
                    .font(.body)
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    TextField("Enter your School or domain", text: $searchText)
                        .textContentType(.organizationName)
                        .foregroundStyle(LoginPalette.inputText)
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
                        ProgressView()
                            .controlSize(.small)
                            .tint(LoginPalette.blue)
                    } else if !searchText.isEmpty {
                        Button("Clear", systemImage: "xmark.circle.fill") {
                            searchText = ""
                            schools = []
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
            }
            .frame(maxWidth: 420)

            if schools.isEmpty && !searching {
                ContentUnavailableView.search(text: searchText)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(schools) { school in
                            Button {
                                selectedSchool = school
                                session.errorMessage = nil
                                mode = .schoolBrowser
                                Task { await signInThroughSchool() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "building.2.fill")
                                        .foregroundStyle(LoginPalette.blue)
                                        .frame(width: 26)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(school.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(LoginPalette.inputText)
                                        if !school.domain.isEmpty {
                                            Text(school.domain)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(maxWidth: 420)
                }
                .scrollIndicators(.hidden)
            }

            instanceSwitch
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
    }

    private var credentials: some View {
        ScrollView {
            VStack(spacing: 20) {
                subpageHeader

                VStack(alignment: .leading, spacing: 7) {
                    if let selectedSchool {
                        Text(selectedSchool.title)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                    } else {
                        Text("Sign in with my account")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)

                VStack(spacing: 0) {
                    credentialField(title: "Username or Email", icon: "person") {
                        TextField("Username or Email", text: $username)
                            .textContentType(.username)
                            .foregroundStyle(LoginPalette.inputText)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            #endif
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                            .onSubmit { focusedField = .password }
                    }

                    Divider().padding(.leading, 46)

                    credentialField(title: "Password", icon: "lock") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .foregroundStyle(LoginPalette.inputText)
                            .focused($focusedField, equals: .password)
                            #if os(iOS)
                            .submitLabel(.go)
                            #endif
                            .onSubmit { signIn() }
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
                .frame(maxWidth: 420)

                Button {
                    signIn()
                } label: {
                    HStack(spacing: 9) {
                        if session.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(session.isLoading ? "Signing in…" : "Sign in")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .foregroundStyle(.white)
                .background(LoginPalette.blue, in: RoundedRectangle(cornerRadius: 5))
                .buttonStyle(.plain)
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || session.isLoading)
                .opacity(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || session.isLoading ? 0.55 : 1)
                .frame(maxWidth: 420)

                instanceSwitch

                Button("I need help signing in") {
                    if let url = URL(string: "https://docs.powerschool.com/SGYH/en/students/schoology-mobile-apps/logging-into-the-schoology-mobile-app-students") {
                        openURL(url)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.92))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if selectedSchool == nil { focusedField = .username }
        }
    }

    private func credentialField<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                content()
                    .textFieldStyle(.plain)
                    .font(.body)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 62)
    }

    private var schoolBrowserProgress: some View {
        VStack(spacing: 24) {
            subpageHeader

            if let selectedSchool {
                Text(selectedSchool.title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            if session.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
                Text("Continue signing in in your browser…")
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            } else {
                Text("School sign-in didn’t complete. You can try again.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Try browser sign-in again") {
                    Task { await signInThroughSchool() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var qrLogin: some View {
        VStack(spacing: 16) {
            subpageHeader

            Text("QR Code Login")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)

            if session.isLoading {
                ProgressView("Signing in to Schoology…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                Text("Scan Your Code")
                    .font(.body)
                    .foregroundStyle(.white)

                QRCodeScannerView { value in
                    Task { await session.signInWithQRCode(value) }
                }
                .frame(maxWidth: 390)
                .frame(height: 300)

                Text("Point your camera at the QR code shown in Schoology.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subpageHeader: some View {
        ZStack {
            SchoologyBrandLockup(compact: true)
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .frame(maxWidth: 420)
        .padding(.bottom, 12)
    }

    private var instanceSwitch: some View {
        Button(canadian ? "I sign in to app.schoology.com" : "I sign in to app.schoologyca.com") {
            canadian.toggle()
            session.canadianServer = canadian
            session.errorMessage = nil
            Task { await SchoologyAPI.shared.setCanadianServer(canadian) }
            UserDefaults.standard.set(canadian, forKey: "schoology.canadian")
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.92))
        .buttonStyle(.plain)
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
            schools = try await SchoologyAPI.shared.searchSchools(query)
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }
}

private enum LoginPalette {
    static let background = Color(red: 68.0 / 255, green: 80.0 / 255, blue: 93.0 / 255)
    static let blue = Color(red: 46.0 / 255, green: 102.0 / 255, blue: 163.0 / 255)
    static let inputText = Color(red: 34.0 / 255, green: 48.0 / 255, blue: 62.0 / 255)
    static let darkButton = Color(red: 34.0 / 255, green: 48.0 / 255, blue: 62.0 / 255)
}

private struct SchoologyBrandLockup: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            SchoologyMark(size: compact ? 27 : 38, letterColor: .white)
            HStack(spacing: 0) {
                Text("School")
                    .foregroundStyle(.white)
                Text("ogy")
                    .foregroundStyle(Color(red: 72.0 / 255, green: 175.0 / 255, blue: 236.0 / 255))
            }
            .font(.system(size: compact ? 23 : 34, weight: .light, design: .rounded))
            .tracking(compact ? -0.7 : -1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schoology")
    }
}

private struct SchoologyMark: View {
    var size: CGFloat
    var letterColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 6.0 / 255, green: 119.0 / 255, blue: 186.0 / 255), lineWidth: max(2, size * 0.075))
            Text("S")
                .font(.system(size: size * 0.63, weight: .medium, design: .rounded))
                .foregroundStyle(letterColor)
                .offset(y: -size * 0.015)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct LoginActionButton: View {
    enum Icon {
        case school, account, qr
    }

    enum Style: Equatable {
        case primary, outlined, qr
    }

    let title: String
    let icon: Icon
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    switch icon {
                    case .school:
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 23, weight: .regular))
                    case .account:
                        SchoologyMark(size: 26, letterColor: LoginPalette.background)
                    case .qr:
                        Image(systemName: "qrcode")
                            .font(.system(size: 25, weight: .regular))
                    }
                }
                .frame(width: 30, height: 30)

                Text(title)
                    .font(.system(size: 16, weight: .regular))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.white)
        .background(background, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(style == .primary ? LoginPalette.blue : .white, lineWidth: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var background: Color {
        switch style {
        case .primary: LoginPalette.blue
        case .outlined: .clear
        case .qr: LoginPalette.darkButton
        }
    }
}
