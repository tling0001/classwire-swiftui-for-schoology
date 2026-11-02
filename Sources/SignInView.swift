import SwiftUI

struct SignInView: View {
    @Environment(AppSession.self) private var session
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
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
        case welcome
        case school
        case credentials
    }

    private enum CredentialField: Hashable {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .welcome:
                    welcome
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .school:
                    schoolPicker
                        .transition(.opacity)
                case .credentials:
                    credentials
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LoginBackdrop()
                    .ignoresSafeArea()
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                if mode != .welcome {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back", systemImage: "chevron.left", action: goBack)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .tint(.primary)
        .onAppear {
            canadian = session.canadianServer
        }
        .alert("Unable to sign in", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: modeKey)
    }

    private var navigationTitle: String {
        switch mode {
        case .welcome: "Welcome"
        case .school: "Find your school"
        case .credentials: "Sign in"
        }
    }

    private var modeKey: Int {
        switch mode {
        case .welcome: 0
        case .school: 1
        case .credentials: 2
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.primary.opacity(0.045))
                        .frame(width: 156, height: 156)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 65, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .padding(28)
                        .glassOrMaterial(cornerRadius: 34)
                }
                .accessibilityHidden(true)

                VStack(spacing: 9) {
                    Text("Schoology")
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.8)

                    Text("Your learning community,\nall in one place.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 36)

            VStack(spacing: 12) {
                loginAction(
                    title: "Continue with your school",
                    subtitle: "Find your school to get started",
                    systemImage: "building.2",
                    prominent: true
                ) {
                    mode = .school
                }

                loginAction(
                    title: "Sign in with username",
                    subtitle: "Use your Schoology account details",
                    systemImage: "person.crop.circle",
                    prominent: false
                ) {
                    selectedSchool = nil
                    mode = .credentials
                }
            }

            Spacer(minLength: 28)

            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                Text("Secure sign in to your school account")
                    .font(.footnote)
            }
            .foregroundStyle(.tertiary)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func loginAction(
        title: String,
        subtitle: String,
        systemImage: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(prominent ? Color.white.opacity(0.82) : Color.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Rectangle())
        }
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .accessibilityHint(subtitle)
        .modifier(AdaptiveLoginButtonStyle(prominent: prominent))
    }

    private var schoolPicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where do you learn?")
                    .font(.title2.bold())
                Text("Search for your school or district to continue.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("School name or domain", text: $searchText)
                    .textContentType(.organizationName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await searchSchools(searchText) } }
                    .onChange(of: searchText) { _, value in
                        Task { await searchSchools(value) }
                    }
                if searching {
                    ProgressView()
                        .controlSize(.small)
                } else if !searchText.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        searchText = ""
                        schools = []
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(15)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
            }
            .padding(.horizontal, 22)

            if schools.isEmpty && !searching {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(schools) { school in
                            Button {
                                selectedSchool = school
                                mode = .credentials
                            } label: {
                                HStack(spacing: 13) {
                                    Image(systemName: "building.2.crop.circle")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 38, height: 38)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(school.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
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
                                .padding(13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .contentShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                }
            }

            Toggle(isOn: $canadian) {
                Label("Canadian Schoology", systemImage: "globe.americas")
            }
            .font(.subheadline)
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var credentials: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(selectedSchool == nil ? "Welcome back" : "Sign in to your school")
                        .font(.largeTitle.bold())
                    Text(selectedSchool?.title ?? "Enter your Schoology account details to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    credentialField(
                        title: "Username or email",
                        icon: "person",
                    ) {
                        TextField("Username or email", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    Divider()
                        .padding(.leading, 48)

                    credentialField(
                        title: "Password",
                        icon: "lock",
                    ) {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { signIn() }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
                }

                Toggle(isOn: $canadian) {
                    Label("Canadian Schoology", systemImage: "globe.americas")
                }
                .font(.subheadline)

                Button(action: signIn) {
                    HStack(spacing: 10) {
                        if session.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                        Text(session.isLoading ? "Signing in…" : "Sign in")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || session.isLoading)
                .modifier(AdaptiveLoginGlass(prominent: true))

                Text("By continuing, you’ll connect securely to your school’s Schoology account.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if selectedSchool == nil {
                focusedField = .username
            }
        }
    }

    private func credentialField<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                content()
                    .textFieldStyle(.plain)
                    .font(.body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .contain)
    }

    private func goBack() {
        focusedField = nil
        switch mode {
        case .welcome: break
        case .school: mode = .welcome
        case .credentials: mode = selectedSchool == nil ? .welcome : .school
        }
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

private struct LoginBackdrop: View {
    var body: some View {
        ZStack {
            Color.clear
            RadialGradient(
                colors: [.primary.opacity(0.055), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
        }
    }
}

private struct AdaptiveLoginButtonStyle: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private extension View {
    @ViewBuilder
    func glassOrMaterial(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
