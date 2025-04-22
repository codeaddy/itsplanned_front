import Foundation

struct YandexGPTMessage: Codable, Identifiable {
    var id: UUID? = UUID()
    let role: String
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case role, text
    }
}

struct YandexGPTRequest: Codable {
    let messages: [YandexGPTMessage]
}

struct YandexGPTResponse: Codable {
    let message: String
}

extension YandexGPTMessage {
    func toChatMessage() -> ChatMessage {
        return ChatMessage(
            content: text,
            isFromUser: role == "user",
            timestamp: Date()
        )
    }
    
    static func fromChatMessage(_ message: ChatMessage) -> YandexGPTMessage {
        return YandexGPTMessage(
            role: message.isFromUser ? "user" : "assistant",
            text: message.content
        )
    }
}
