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
    @Published var organizerName: String = ""
    
    let baseURL = "http://localhost:8080"
    
    // Fetch event participants with detailed information
    func fetchParticipants(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // First, fetch the event details to get the organizer ID
            guard let eventUrl = URL(string: "\(baseURL)/events/\(eventId)") else {
                throw EventDetailError.invalidURL
            }
            
            var eventRequest = URLRequest(url: eventUrl)
            eventRequest.httpMethod = "GET"
            eventRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (eventData, eventResponse) = try await URLSession.shared.data(for: eventRequest)
            
            guard let eventHttpResponse = eventResponse as? HTTPURLResponse else {
                throw EventDetailError.invalidResponse
            }
            
            // Check if we got a valid response for the event details
            guard eventHttpResponse.statusCode == 200 else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: eventData)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to fetch event details")
            }
            
            // Decode the event details to get the organizer ID
            let eventResponseObj = try JSONDecoder().decode(APIResponse<EventResponse>.self, from: eventData)
            guard let event = eventResponseObj.data else {
                throw EventDetailError.apiError("Failed to parse event data")
            }
            
            // Now fetch the participants list
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
                
                // Unfortunately, the API doesn't give us user IDs along with names in the participants list
                // So we can't directly match organizerId with participants
                // As a workaround, we'll assume the organizer is the first participant
                
                // Store the name of the organizer (first participant)
                if !participantsResponse.participants.isEmpty {
                    self.organizerName = participantsResponse.participants[0]
                }
                
                // Convert string array to Participant objects with proper roles
                self.participants = participantsResponse.participants.enumerated().map { index, participantName in
                    // The first participant (index 0) is the organizer
                    let isOrganizer = index == 0
                    
                    return Participant(
                        name: participantName,
                        role: isOrganizer ? "Организатор" : "Участник",
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
        organizerName = "Иван Иванов"
    }
} 
