import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "Events")

@MainActor
final class EventViewModel: ObservableObject {
    @Published var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var error: String?
    
    func fetchEvents() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                error = "Не авторизован"
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events") else {
                error = "Некорректный URL"
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Некорректный ответ сервера"
                return
            }
            
            if httpResponse.statusCode == 200 {
                let eventsResponse = try JSONDecoder().decode(APIResponse<[EventResponse]>.self, from: data)
                if let events = eventsResponse.data {
                    self.events = events.sorted { $0.eventDateTime < $1.eventDateTime }
                }
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                error = errorResponse.error ?? "Не удалось загрузить мероприятия"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func createEvent(name: String, description: String?, date: Date, place: String?, initialBudget: Double?) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                error = "Не авторизован"
                return
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events") else {
                error = "Некорректный URL"
                return
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let eventDateTime = dateFormatter.string(from: date)
            
            let createEventRequest = CreateEventRequest(
                name: name,
                description: description,
                eventDateTime: eventDateTime,
                place: place,
                initialBudget: initialBudget
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(createEventRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Некорректный ответ сервера"
                return
            }
            
            if httpResponse.statusCode == 200 {
                await fetchEvents()
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                error = errorResponse.error ?? "Не удалось создать мероприятие"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
} 
