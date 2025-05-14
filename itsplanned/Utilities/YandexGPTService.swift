import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "YandexGPT")

private let SERVICE_SYSTEM_PROMPT = """
You are an AI assistant for the itsPlanned application, which helps users plan events and organize parties.
Be concise, helpful, and friendly in your responses.
Use appropriate emojis in your responses to make them more engaging and lively. 
Incorporate emojis that match the context of events, parties, or whatever the user is discussing.
Focus on providing practical advice related to event planning, parties, celebrations, and social gatherings.
Your responses should be warm, enthusiastic, and include emojis to convey emotions.
"""

class YandexGPTService {
    static let shared = YandexGPTService()
    
    private init() {}
    
    func sendChatRequest(messages: [ChatMessage]) async throws -> String {
        var gptMessages = messages.map { YandexGPTMessage.fromChatMessage($0) }
        
        // Add system prompt as the first message
        gptMessages.insert(YandexGPTMessage(role: "system", text: SERVICE_SYSTEM_PROMPT), at: 0)
        
        let request = YandexGPTRequest(messages: gptMessages)
        
        let jsonData = try JSONEncoder().encode(request)
        
        guard let url = URL(string: "\(APIConfig.baseURL)/ai/message") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await KeychainManager.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonData
        
        logger.debug("Sending request to Yandex GPT: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        logger.debug("Received response: \(String(data: data, encoding: .utf8) ?? "")")
        
        if httpResponse.statusCode == 200 {
            let gptResponse = try JSONDecoder().decode(YandexGPTResponse.self, from: data)
            return gptResponse.message
        } else {
            let errorResponse = try? JSONDecoder().decode([String: String].self, from: data)
            if let errorResponse = errorResponse,
               let errorMessage = errorResponse["error"] {
                throw NSError(domain: "YandexGPTError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            } else {
                throw NSError(domain: "YandexGPTError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            }
        }
    }
} 
