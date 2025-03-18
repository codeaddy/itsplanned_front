import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "Chat")

// Models for Chat functionality
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct ChatThread: Identifiable {
    let id = UUID()
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
        let now = Date()
        
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

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var chatThreads: [ChatThread] = []
    @Published var currentMessages: [ChatMessage] = []
    @Published var messageText: String = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    init() {
        loadTestData()
    }
    
    func sendMessage(threadId: UUID, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Create user message
        let userMessage = ChatMessage(
            content: content,
            isFromUser: true,
            timestamp: Date()
        )
        
        // Add to current messages
        currentMessages.append(userMessage)
        
        // Update the thread if applicable
        if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
            chatThreads[index].messages.append(userMessage)
            updateChatThread(threadId: threadId, lastMessage: content, lastMessageDate: Date())
        }
        
        // Clear the input field
        messageText = ""
        
        // Simulate AI assistant reply after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.simulateAIResponse(threadId: threadId)
        }
    }
    
    private func simulateAIResponse(threadId: UUID) {
        let responses = [
            "Я могу помочь вам организовать мероприятие. Расскажите подробнее о ваших планах.",
            "Отличная идея! Давайте разработаем план для этого события.",
            "Для этого типа мероприятия я бы рекомендовал следующие шаги...",
            "Я могу предложить несколько вариантов. Что вы думаете о...",
            "Исходя из вашего описания, вот что я могу предложить...",
            "Это звучит интересно! Какие еще детали вы можете рассказать?",
            "Я проанализировал ваш запрос и могу предложить оптимальное решение.",
            "Было бы полезно знать бюджет мероприятия. Это поможет мне дать более точные рекомендации."
        ]
        
        // Get random response
        let aiResponse = responses.randomElement() ?? "Я помогу вам с организацией мероприятия."
        
        // Create AI message
        let aiMessage = ChatMessage(
            content: aiResponse,
            isFromUser: false,
            timestamp: Date()
        )
        
        // Add to current messages
        currentMessages.append(aiMessage)
        
        // Update the thread if applicable
        if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
            chatThreads[index].messages.append(aiMessage)
            updateChatThread(threadId: threadId, lastMessage: aiResponse, lastMessageDate: Date())
        }
    }
    
    func createNewChat() -> UUID {
        let newChatId = UUID()
        
        // Create initial assistant messages
        let welcomeMessage = ChatMessage(
            content: "Привет! Чем я могу тебе помочь?",
            isFromUser: false,
            timestamp: Date()
        )
        
        let suggestionsMessage = ChatMessage(
            content: "Давай вместе придумаем самую крутую вечеринку! Расскажи мне о твоих запросах, количестве человек и локации мероприятия",
            isFromUser: false,
            timestamp: Date().addingTimeInterval(1)
        )
        
        // Create a new chat with default title
        let newChat = ChatThread(
            title: "Новый чат",
            lastMessage: suggestionsMessage.content,
            lastMessageDate: Date(),
            messages: [welcomeMessage, suggestionsMessage]
        )
        
        // Add to chat threads
        chatThreads.insert(newChat, at: 0)
        
        // Set current messages
        currentMessages = newChat.messages
        
        return newChatId
    }
    
    func loadChat(threadId: UUID) {
        if let chat = chatThreads.first(where: { $0.id == threadId }) {
            currentMessages = chat.messages
        }
    }
    
    // Load test data for previews and initial testing
    func loadTestData() {
        let thread1Messages: [ChatMessage] = [
            ChatMessage(content: "Привет! Чем я могу тебе помочь?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2)),
            ChatMessage(content: "Давай вместе придумаем самую крутую вечеринку! Расскажи мне о твоих запросах, количестве человек и локации мероприятия", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 1)),
            ChatMessage(content: "Я хочу организовать день рождения на 25 человек. Предложи мне различные идеи проведения мероприятия!", isFromUser: true, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 120)),
            ChatMessage(content: "Вот ваше эссе на 500 слов....", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 240))
        ]
        
        let thread2Messages: [ChatMessage] = [
            ChatMessage(content: "Привет! Чем я могу тебе помочь?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 5)),
            ChatMessage(content: "Мне нужна помощь с организацией корпоратива", isFromUser: true, timestamp: Date().addingTimeInterval(-3600 * 5 + 60)),
            ChatMessage(content: "Конечно! Я могу помочь с организацией корпоратива. Расскажите подробнее о ваших планах: количество участников, предпочтительное место, бюджет и тематика мероприятия?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 5 + 120))
        ]
        
        let thread3Messages: [ChatMessage] = [
            ChatMessage(content: "Привет! Чем я могу тебе помочь?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 7)),
            ChatMessage(content: "Мне нужно организовать свадьбу", isFromUser: true, timestamp: Date().addingTimeInterval(-3600 * 24 * 7 + 300)),
            ChatMessage(content: "Поздравляю! Организация свадьбы - это важное и радостное событие. Я помогу вам спланировать этот особенный день. Сколько гостей вы планируете пригласить? Есть ли уже выбранная дата?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 7 + 400))
        ]
        
        chatThreads = [
            ChatThread(title: "Организация дня рождения", lastMessage: thread1Messages.last!.content, lastMessageDate: thread1Messages.last!.timestamp, messages: thread1Messages),
            ChatThread(title: "Корпоратив", lastMessage: thread2Messages.last!.content, lastMessageDate: thread2Messages.last!.timestamp, messages: thread2Messages),
            ChatThread(title: "Свадьба", lastMessage: thread3Messages.last!.content, lastMessageDate: thread3Messages.last!.timestamp, messages: thread3Messages)
        ]
    }
    
    // Function to update chat thread properties
    func updateChatThread(threadId: UUID, title: String? = nil, lastMessage: String? = nil, lastMessageDate: Date? = nil) {
        if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
            if let title = title {
                chatThreads[index].title = title
            }
            
            if let lastMessage = lastMessage {
                chatThreads[index].lastMessage = lastMessage
            }
            
            if let lastMessageDate = lastMessageDate {
                chatThreads[index].lastMessageDate = lastMessageDate
            }
        }
    }
    
    // Get chat title by ID
    func getChatTitle(for id: UUID) -> String {
        if let chat = chatThreads.first(where: { $0.id == id }) {
            return chat.title
        }
        return "Чат с ассистентом"
    }
} 