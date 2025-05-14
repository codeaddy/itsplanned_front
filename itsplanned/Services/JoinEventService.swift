import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "JoinEvent")

class JoinEventService {
    static let shared = JoinEventService()
    
    private init() {}
    
    func joinEvent(code: String) async -> (success: Bool, message: String?) {
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                return (false, "Не авторизован")
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events/join/\(code)") else {
                return (false, "Некорректный URL")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Некорректный ответ сервера")
            }
            
            if httpResponse.statusCode == 200 {
                let successResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                logger.info("Successfully joined event: \(successResponse.message ?? "")")
                return (true, successResponse.message)
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                logger.error("Failed to join event: \(errorResponse.error ?? "Unknown error")")
                return (false, errorResponse.error)
            }
        } catch {
            logger.error("Error joining event: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }
} 