import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "YandexGPT")

// System prompt for Yandex GPT
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
    
    private let baseURL = "http://localhost:8080"
    
    private init() {}
    
    func sendChatRequest(messages: [ChatMessage]) async throws -> String {
        var gptMessages = messages.map { YandexGPTMessage.fromChatMessage($0) }
        
        // Add system prompt as the first message
        gptMessages.insert(YandexGPTMessage(role: "system", text: SERVICE_SYSTEM_PROMPT), at: 0)
        
        // Create request
        let request = YandexGPTRequest(messages: gptMessages)
        
        // Encode request
        let jsonData = try JSONEncoder().encode(request)
        
        // Set up URLRequest
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization if user is logged in
        if let token = try? await KeychainManager.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonData
        
        logger.debug("Sending request to Yandex GPT: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        logger.debug("Received response: \(String(data: data, encoding: .utf8) ?? "")")
        
        if httpResponse.statusCode == 200 {
            // Decode the response
            let gptResponse = try JSONDecoder().decode(YandexGPTResponse.self, from: data)
            return gptResponse.message
        } else {
            // Attempt to decode error response
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