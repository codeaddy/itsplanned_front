import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "Participants")

struct Participant: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let avatar: String?
}

@MainActor
final class ParticipantsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var participants: [Participant] = []
    @Published var filteredParticipants: [Participant] = []
    @Published var searchText: String = ""
    
    let baseURL = "http://localhost:8080"
    
    // Fetch event participants with detailed information
    func fetchParticipants(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/{id}/participants endpoint
            guard let url = URL(string: "\(baseURL)/events/\(eventId)/participants") else {
                throw EventDetailError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventDetailError.invalidResponse
            }
            
            // For debugging - print full response details
            print("Participants API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Participants JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                // Direct decoding of EventParticipantsResponse for 200 status
                let participantsResponse = try JSONDecoder().decode(EventParticipantsResponse.self, from: data)
                
                // Convert string array to Participant objects
                self.participants = participantsResponse.participants.map { participantName in
                    // In a real app, we would parse role and avatar information from the API
                    // For now, we'll create test data with random roles
                    let roles = ["Организатор", "Участник", "Гость"]
                    let randomRole = roles[Int.random(in: 0..<roles.count)]
                    
                    return Participant(
                        name: participantName,
                        role: randomRole,
                        avatar: nil
                    )
                }
                
                // Initialize filtered participants with all participants
                self.filteredParticipants = self.participants
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Handle authorization errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.error ?? "You are not authorized to view this event"
                throw EventDetailError.apiError(errorMessage)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to fetch participants")
            }
        } catch {
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error fetching participants: \(error.localizedDescription)")
        }
    }
    
    // Filter participants based on search text
    func filterParticipants() {
        if searchText.isEmpty {
            filteredParticipants = participants
        } else {
            filteredParticipants = participants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Load test data for preview
    func loadTestData() {
        let testParticipants = [
            Participant(name: "Иван Иванов", role: "Организатор", avatar: nil),
            Participant(name: "Мария Петрова", role: "Участник", avatar: nil),
            Participant(name: "Алексей Смирнов", role: "Участник", avatar: nil),
            Participant(name: "Екатерина Соколова", role: "Участник", avatar: nil),
            Participant(name: "Дмитрий Козлов", role: "Участник", avatar: nil),
        ]
        
        participants = testParticipants
        filteredParticipants = testParticipants
    }
} 
