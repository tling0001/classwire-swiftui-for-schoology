import SwiftUI

struct ClassWireAIWelcomeView: View {
    let provider: ClassWireAIProvider
    let isProviderConfigured: Bool
    let onConfigureProvider: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("CLASSWIRE AI", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(SchoologyStyle.blue)
                    Text("Your Schoology learning assistant")
                        .font(.largeTitle.weight(.bold))
                    Text("Ask questions about courses, assignments, grades, resources, upcoming work, and messages. Before you begin, here's how to set it up and what happens to your data.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("1. Choose an AI provider", systemImage: "cpu")
                            .font(.headline)
                        Text("ClassWire supports Google Gemini, OpenAI, Anthropic, Ollama, and Puter. Your selected provider is currently \(provider.title).")
                            .foregroundStyle(.secondary)
                        if isProviderConfigured {
                            Label("Provider setup is ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Provider setup is not complete yet", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        Button(isProviderConfigured ? "Review AI settings" : "Set up \(provider.title)", systemImage: "gearshape") {
                            onConfigureProvider()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("How your data is used") {
                    VStack(alignment: .leading, spacing: 12) {
                        privacyRow("Your prompt and relevant Schoology information retrieved to answer it are sent directly to the AI provider you select. Your Schoology password and OAuth token are used for Schoology API access and are not included in the AI prompt.", symbol: "arrow.up.right")
                        privacyRow("The provider processes that information under its own privacy policy and terms. Review those terms before using the service.", symbol: "building.2")
                        privacyRow("Provider API keys and Google refresh tokens are stored in Apple Keychain; Puter sign-in remains in its WebKit session. AI conversation history is saved locally on this device.", symbol: "lock.shield")
                        privacyRow("ClassWire only performs supported Schoology changes after you review and explicitly confirm the proposed action.", symbol: "checkmark.shield")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label("AI can make mistakes. Check important information, grades, due dates, and messages in Schoology before relying on it.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Continue to ClassWire AI", systemImage: "arrow.right", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(.background)
    }

    private func privacyRow(_ message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
