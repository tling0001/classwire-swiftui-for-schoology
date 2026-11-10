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

struct ClassWireAIFileAttachment: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let mimeType: String
    let data: Data
    let extractedText: String

    init(filename: String, mimeType: String, data: Data, extractedText: String = "") {
        id = UUID()
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.extractedText = extractedText
    }

    var isImage: Bool { mimeType.lowercased().hasPrefix("image/") }
    var isPDF: Bool { mimeType.lowercased() == "application/pdf" }
}

struct ClassWireAIMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var attachments: [ClassWireAIFileAttachment] = []

    private enum CodingKeys: String, CodingKey {
        case id, role, content, createdAt
    }

    init(role: String, content: String, attachments: [ClassWireAIFileAttachment] = [], createdAt: Date = .now) {
        id = UUID()
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        role = try values.decode(String.self, forKey: .role)
        content = try values.decode(String.self, forKey: .content)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        attachments = []
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(role, forKey: .role)
        try values.encode(content, forKey: .content)
        try values.encode(createdAt, forKey: .createdAt)
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
