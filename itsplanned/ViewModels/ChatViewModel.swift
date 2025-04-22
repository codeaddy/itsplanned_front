import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "Chat")

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var chatThreads: [ChatThread] = []
    @Published var currentMessages: [ChatMessage] = []
    @Published var messageText: String = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    init() {
        loadSavedChats()
    }
    
    func loadSavedChats() {
        chatThreads = ChatStorageService.shared.loadChatThreads()
        
        if chatThreads.isEmpty {
            loadTestData()
        }
    }
    
    func sendMessage(threadId: UUID, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = ChatMessage(
            content: content,
            isFromUser: true,
            timestamp: Date()
        )
        
        currentMessages.append(userMessage)
        
        if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
            chatThreads[index].messages.append(userMessage)
            
            if chatThreads[index].title == "Новый чат" {
                let firstSentence = content.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? content
                let truncatedTitle = firstSentence.count > 30 ? String(firstSentence.prefix(30)) + "..." : firstSentence
                updateChatThread(threadId: threadId, title: truncatedTitle, lastMessage: content, lastMessageDate: Date())
            } else {
                updateChatThread(threadId: threadId, lastMessage: content, lastMessageDate: Date())
            }
            
            ChatStorageService.shared.saveChatThread(chatThreads[index])
        }
        
        messageText = ""
        
        isLoading = true
        
        Task {
            do {
                let aiResponse = try await YandexGPTService.shared.sendChatRequest(messages: currentMessages)
                
                let aiMessage = ChatMessage(
                    content: aiResponse,
                    isFromUser: false,
                    timestamp: Date()
                )
                
                currentMessages.append(aiMessage)
                
                if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
                    chatThreads[index].messages.append(aiMessage)
                    updateChatThread(threadId: threadId, lastMessage: aiResponse, lastMessageDate: Date())
                    
                    ChatStorageService.shared.saveChatThread(chatThreads[index])
                }
                
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Не удалось получить ответ: \(error.localizedDescription)"
                showError = true
                logger.error("Failed to get AI response: \(error.localizedDescription)")
            }
        }
    }
    
    func createNewChat() -> UUID {
        let newChatId = UUID()
        
        let welcomeMessage = ChatMessage(
            content: "Привет! Чем я могу тебе помочь?",
            isFromUser: false,
            timestamp: Date()
        )
        
        let suggestionsMessage = ChatMessage(
            content: "Давай вместе придумаем самую крутую вечеринку! Расскажи мне о твоих запросах, количестве человек и локации мероприятия.",
            isFromUser: false,
            timestamp: Date().addingTimeInterval(1)
        )
        
        let newChat = ChatThread(
            id: newChatId,
            title: "Новый чат",
            lastMessage: suggestionsMessage.content,
            lastMessageDate: Date(),
            messages: [welcomeMessage, suggestionsMessage]
        )
        
        chatThreads.insert(newChat, at: 0)
        
        currentMessages = newChat.messages
        
        ChatStorageService.shared.saveChatThread(newChat)
        
        return newChatId
    }
    
    func loadChat(threadId: UUID) {
        if let storedChat = ChatStorageService.shared.getChatThread(id: threadId) {
            if let index = chatThreads.firstIndex(where: { $0.id == threadId }) {
                chatThreads[index] = storedChat
            } else {
                chatThreads.append(storedChat)
            }
            currentMessages = storedChat.messages
        } else if let chat = chatThreads.first(where: { $0.id == threadId }) {
            currentMessages = chat.messages
        }
    }
    
    func loadTestData() {
        let thread1Messages: [ChatMessage] = [
            ChatMessage(content: "Привет! Чем я могу тебе помочь?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2)),
            ChatMessage(content: "Давай вместе придумаем самую крутую вечеринку! Расскажи мне о твоих запросах, количестве человек и локации мероприятия", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 1)),
            ChatMessage(content: "Я хочу организовать день рождения на 25 человек. Предложи мне различные идеи проведения мероприятия!", isFromUser: true, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 120)),
            ChatMessage(content: "Для дня рождения на 25 человек есть множество интересных вариантов!\n\n1. **Тематическая вечеринка**. Выберите тему, которая нравится имениннику: ретро 80-х, Гэтсби, супергерои, Гарри Поттер, кино. Гости могут прийти в соответствующих костюмах, а декор, еда и активности будут поддерживать тематику.\n\n2. **Квест или escape room**. Арендуйте готовый квеструм или организуйте собственный квест на природе или в помещении. Разделите гостей на команды для более динамичного прохождения.\n\n3. **Барбекю или пикник в парке**. Неформальное мероприятие на свежем воздухе с играми, музыкой и вкусной едой.\n\n4. **Аренда банкетного зала с развлекательной программой**. Пригласите ведущего, который организует конкурсы, или музыкальную группу/DJ.\n\n5. **Активный отдых**: боулинг, картинг, пейнтбол, лазертаг или веревочный парк — отличный вариант для любителей движения.\n\n6. **Кулинарный мастер-класс**. Пригласите шеф-повара, который научит гостей готовить интересные блюда, а потом все вместе насладятся результатом.\n\n7. **Творческий мастер-класс**: рисование, гончарное дело, изготовление свечей или других предметов. Гости получат новые навыки и сувениры на память.\n\nЧто из этого больше всего подходит имениннику и вашим гостям?", isFromUser: false, timestamp: Date().addingTimeInterval(-3600 * 24 * 2 + 240))
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
            ChatThread(id: UUID(), title: "Организация дня рождения", lastMessage: thread1Messages.last!.content, lastMessageDate: thread1Messages.last!.timestamp, messages: thread1Messages),
            ChatThread(id: UUID(), title: "Корпоратив", lastMessage: thread2Messages.last!.content, lastMessageDate: thread2Messages.last!.timestamp, messages: thread2Messages),
            ChatThread(id: UUID(), title: "Свадьба", lastMessage: thread3Messages.last!.content, lastMessageDate: thread3Messages.last!.timestamp, messages: thread3Messages)
        ]
        
        for thread in chatThreads {
            ChatStorageService.shared.saveChatThread(thread)
        }
    }
    
    func deleteChat(at indexSet: IndexSet) {
        for index in indexSet {
            let threadId = chatThreads[index].id
            ChatStorageService.shared.deleteChatThread(id: threadId)
        }
        chatThreads.remove(atOffsets: indexSet)
    }
    
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
    
    func getChatTitle(for id: UUID) -> String {
        if let chat = chatThreads.first(where: { $0.id == id }) {
            return chat.title
        }
        return "Чат с ассистентом"
    }
} 