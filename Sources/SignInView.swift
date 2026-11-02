import SwiftUI

struct SignInView: View {
    @Environment(AppSession.self) private var session
    @State private var mode: Mode = .welcome
    @State private var searchText = ""
    @State private var schools: [SchoologySchool] = []
    @State private var selectedSchool: SchoologySchool?
    @State private var username = ""
    @State private var password = ""
    @State private var canadian = false
    @State private var searching = false

    enum Mode { case welcome, school, credentials }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .welcome: welcome
                case .school: schoolPicker
                case .credentials: credentials
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [SchoologyStyle.deepBlue.opacity(0.08), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle(mode == .welcome ? "Schoology" : mode == .school ? "Find your school" : "Sign in")
            .toolbar {
                if mode != .welcome {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back", systemImage: "chevron.left") {
                            mode = mode == .credentials ? .school : .welcome
                        }
                    }
                }
            }
        }
        .onAppear { canadian = session.canadianServer }
        .alert("Unable to sign in", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK") { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 58, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, SchoologyStyle.blue)
                .padding(24)
                .background(SchoologyStyle.blue, in: RoundedRectangle(cornerRadius: 28))
            Text("Schoology")
                .font(.largeTitle.bold())
            Text("Connect with your school and stay on top of learning.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Button("Sign in through my school", systemImage: "building.2.fill") {
                    mode = .school
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                Button("Sign in with my account", systemImage: "person.crop.circle") {
                    selectedSchool = nil
                    mode = .credentials
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            Spacer()
            Text("Schoology • 2026.10.0")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
    }

    private var schoolPicker: some View {
        VStack(spacing: 14) {
            TextField("Enter your school or domain", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, value in
                    Task { await searchSchools(value) }
                }
            if searching { ProgressView() }
            List(schools) { school in
                Button {
                    selectedSchool = school
                    mode = .credentials
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(school.title).foregroundStyle(.primary)
                        if !school.domain.isEmpty {
                            Text(school.domain).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            Toggle("Use Canadian Schoology", isOn: $canadian)
                .padding(.horizontal)
        }
        .padding()
    }

    private var credentials: some View {
        Form {
            if let selectedSchool {
                LabeledContent("School", value: selectedSchool.title)
            }
            TextField("Username or email", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textContentType(.password)
            Toggle("Canadian Schoology", isOn: $canadian)
            Button {
                Task {
                    await session.signIn(
                        username: username,
                        password: password,
                        schoolID: selectedSchool?.id,
                        canadian: canadian
                    )
                }
            } label: {
                if session.isLoading { ProgressView() } else { Text("Sign in") }
            }
            .disabled(username.isEmpty || password.isEmpty || session.isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func searchSchools(_ query: String) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            schools = []
            return
        }
        searching = true
        defer { searching = false }
        do { schools = try await SchoologyAPI.shared.searchSchools(query) }
        catch { session.errorMessage = error.localizedDescription }
    }
}
