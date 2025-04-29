import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "ChatStorage")

class ChatStorageService {
    static let shared = ChatStorageService()
    
    private let chatThreadsKey = "ChatThreads"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func saveChatThreads(_ chatThreads: [ChatThread]) {
        do {
            let data = try JSONEncoder().encode(chatThreads)
            userDefaults.set(data, forKey: chatThreadsKey)
            logger.debug("Saved \(chatThreads.count) chat threads to storage")
        } catch {
            logger.error("Failed to save chat threads: \(error.localizedDescription)")
        }
    }
    
    func loadChatThreads() -> [ChatThread] {
        guard let data = userDefaults.data(forKey: chatThreadsKey) else {
            logger.debug("No chat threads found in storage")
            return []
        }
        
        do {
            let chatThreads = try JSONDecoder().decode([ChatThread].self, from: data)
            logger.debug("Loaded \(chatThreads.count) chat threads from storage")
            return chatThreads
        } catch {
            logger.error("Failed to load chat threads: \(error.localizedDescription)")
            return []
        }
    }
    
    func saveChatThread(_ chatThread: ChatThread) {
        var chatThreads = loadChatThreads()
        
        // Update or add the thread
        if let index = chatThreads.firstIndex(where: { $0.id == chatThread.id }) {
            chatThreads[index] = chatThread
        } else {
            chatThreads.append(chatThread)
        }
        
        saveChatThreads(chatThreads)
    }
    
    func deleteChatThread(id: UUID) {
        var chatThreads = loadChatThreads()
        chatThreads.removeAll(where: { $0.id == id })
        saveChatThreads(chatThreads)
    }
    
    func getChatThread(id: UUID) -> ChatThread? {
        let chatThreads = loadChatThreads()
        return chatThreads.first(where: { $0.id == id })
    }
    
    func clearAllChats() {
        userDefaults.removeObject(forKey: chatThreadsKey)
        logger.debug("Cleared all chat threads from storage")
    }
} 
