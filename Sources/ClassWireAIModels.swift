import Foundation

enum ClassWireAIProvider: String, CaseIterable, Codable, Identifiable, Equatable {
    case gemini
    case openai
    case anthropic
    case ollama
    case puter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gemini: "Google Gemini"
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .ollama: "Ollama (local)"
        case .puter: "Puter"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini: "gemini-3.8-flash"
        case .openai: "gpt-4.1-mini"
        case .anthropic: "claude-sonnet-4-20250514"
        case .ollama: "qwen3:8b"
        case .puter: "gpt-4.1-mini"
        }
    }

    var requiresAPIKey: Bool { self != .ollama && self != .puter }
}

struct ClassWireAIMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: String
    var content: String
    var createdAt: Date

    init(role: String, content: String, createdAt: Date = .now) {
        id = UUID()
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct ClassWireAIConversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ClassWireAIMessage]
    var updatedAt: Date

    init(title: String = "New conversation") {
        id = UUID()
        self.title = title
        messages = []
        updatedAt = .now
    }
}

struct ClassWireAIPendingAction: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let values: [String: String]
    let title: String
    let summary: String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct ClassWireAINavigationRequest: Equatable {
    let kind: String
    let id: String
    let sectionID: String?
    let title: String
}

enum ClassWireAIError: LocalizedError {
    case missingKey(String)
    case invalidModel
    case invalidResponse(String)
    case unsupportedProvider
    case action(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider): "Add an API key for \(provider) in ClassWire AI settings."
        case .invalidModel: "Enter a valid model name."
        case .invalidResponse(let detail): detail
        case .unsupportedProvider: "Choose Gemini, OpenAI, Anthropic, Ollama, or Puter."
        case .action(let detail): detail
        }
    }
}
