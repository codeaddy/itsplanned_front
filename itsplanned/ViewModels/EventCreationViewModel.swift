import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "EventCreation")

@MainActor
final class EventCreationViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var date: Date = Date()
    @Published var place: String = ""
    @Published var budget: String = ""
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published private(set) var isLoading = false
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    var isValid: Bool {
        !title.isEmpty
    }
    
    func createEvent() async -> Bool {
        guard isValid else { return false }
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventError.unauthorized
            }
            
            let eventDateTimeString = dateFormatter.string(from: date)
            logger.debug("Formatted date: \(eventDateTimeString)")
            
            var budgetValue: Double? = nil
            if !budget.isEmpty {
                let sanitizedBudget = budget.replacingOccurrences(of: ",", with: ".")
                if let value = Double(sanitizedBudget) {
                    budgetValue = value
                }
            }
            
            let eventRequest = CreateEventRequest(
                name: title,
                description: description.isEmpty ? nil : description,
                eventDateTime: eventDateTimeString,
                place: place.isEmpty ? nil : place,
                initialBudget: budgetValue
            )
            
            let jsonData = try JSONEncoder().encode(eventRequest)
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events") else {
                throw EventError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventError.invalidResponse
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                logger.debug("Event created successfully with status code: \(httpResponse.statusCode)")
                NotificationCenter.default.post(name: .eventCreated, object: nil)
                return true
            } else {
                do {
                    let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                    throw EventError.apiError(errorResponse.error ?? "Failed to create event")
                } catch {
                    throw EventError.apiError("Server returned status code: \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            showError = true
            if let eventError = error as? EventError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error creating event: \(error.localizedDescription)")
            return false
        }
    }
}

enum EventError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case apiError(String)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized"
        case .apiError(let message):
            return message
        }
    }
}

extension Notification.Name {
    static let eventCreated = Notification.Name("eventCreated")
} 