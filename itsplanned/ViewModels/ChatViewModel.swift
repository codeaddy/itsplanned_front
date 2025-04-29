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
