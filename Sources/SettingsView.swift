import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { session.appearance },
                    set: { session.appearance = $0 }
                )) {
                    Text("System").tag(AppAppearance.system)
                    Text("Light").tag(AppAppearance.light)
                    Text("Dark").tag(AppAppearance.dark)
                }
            }
            Section("Account") {
                if let user = session.user {
                    LabeledContent("Signed in as", value: user.nameDisplay)
                }
                Button("Sign out", role: .destructive) {
                    session.signOut()
                }
            }
            Section("About") {
                LabeledContent("Version", value: "2026.10.0")
                LabeledContent("Bundle identifier", value: "com.schoologytauri.app")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(maxWidth: 720)
    }
}
