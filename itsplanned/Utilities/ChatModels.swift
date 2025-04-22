import Foundation

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content, isFromUser, timestamp
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct ChatThread: Identifiable, Codable {
    let id: UUID
    var title: String
    var lastMessage: String
    var lastMessageDate: Date
    var messages: [ChatMessage]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: lastMessageDate)
    }
    
    var shortFormattedDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastMessageDate) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: lastMessageDate)
        } else if calendar.isDateInYesterday(lastMessageDate) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: lastMessageDate)
        }
    }
} 