import Foundation
import OSLog
import SwiftUI

// Import models from their proper locations
// No need to import SwiftUI twice

private let logger = Logger(subsystem: "com.itsplanned", category: "EventDetails")

// Define the EventError enum
enum EventDetailError: Error {
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

@MainActor
final class EventDetailsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var participants: [String] = []
    @Published var spentBudget: Double = 0
    @Published var initialBudget: Double = 0
    @Published var leaderboard: [EventLeaderboardEntry] = []
    @Published var hasAccess: Bool = true
    @Published var isOwner: Bool = false
    @Published var showShareLinkCopied: Bool = false
    
    // Edit mode properties
    @Published var isEditingName: Bool = false
    @Published var isEditingDescription: Bool = false
    @Published var isEditingDateTime: Bool = false
    @Published var isEditingPlace: Bool = false
    @Published var isEditingBudget: Bool = false
    
    // Edited values
    @Published var editedName: String = ""
    @Published var editedDescription: String = ""
    @Published var editedDateTime: Date = Date()
    @Published var editedPlace: String = ""
    @Published var editedBudget: String = ""
    
    let baseURL = "http://localhost:8080"
    
    // Fetch event participants
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
                self.participants = participantsResponse.participants
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
    
    // Fetch event budget information
    func fetchBudgetInfo(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/{id}/budget endpoint
            guard let url = URL(string: "\(baseURL)/events/\(eventId)/budget") else {
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
            print("Budget API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Budget JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                let budgetResponse = try JSONDecoder().decode(APIResponse<EventBudgetResponse>.self, from: data)
                if let budget = budgetResponse.data {
                    self.initialBudget = budget.initialBudget
                    self.spentBudget = budget.realBudget
                }
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Handle authorization errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.error ?? "You are not authorized to view this event's budget"
                throw EventDetailError.apiError(errorMessage)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to fetch budget info")
            }
        } catch {
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error fetching budget info: \(error.localizedDescription)")
        }
    }
    
    // Fetch event leaderboard
    func fetchLeaderboard(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/{id}/leaderboard endpoint
            guard let url = URL(string: "\(baseURL)/events/\(eventId)/leaderboard") else {
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
            print("Leaderboard API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Leaderboard JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                let leaderboardResponse = try JSONDecoder().decode(APIResponse<EventLeaderboardResponse>.self, from: data)
                if let leaderboardData = leaderboardResponse.data {
                    self.leaderboard = leaderboardData.leaderboard
                }
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Handle authorization errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.error ?? "You are not authorized to view this event's leaderboard"
                throw EventDetailError.apiError(errorMessage)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to fetch leaderboard")
            }
        } catch {
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error fetching leaderboard: \(error.localizedDescription)")
        }
    }
    
    // Generate invite link
    func generateInviteLink(eventId: Int) async -> String? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/invite endpoint
            guard let url = URL(string: "\(baseURL)/events/invite") else {
                throw EventDetailError.invalidURL
            }
            
            let inviteRequest = GenerateInviteLinkRequest(eventId: eventId)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(inviteRequest)
            
            // Print request body for debugging
            if let requestBody = request.httpBody {
                printJSON(requestBody, label: "Invite Link Request")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventDetailError.invalidResponse
            }
            
            // Print response for debugging
            print("Invite Link Response Status: \(httpResponse.statusCode)")
            printJSON(data, label: "Invite Link Response")
            
            if httpResponse.statusCode == 200 {
                // Try to decode the response directly first
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let inviteLink = json["invite_link"] as? String {
                    print("Successfully extracted invite_link from JSON dictionary")
                    return inviteLink
                }
                
                // If direct decoding fails, try the wrapped version
                if let inviteResponse = try? JSONDecoder().decode(APIResponse<GenerateInviteLinkResponse>.self, from: data),
                   let inviteData = inviteResponse.data {
                    print("Successfully decoded APIResponse<GenerateInviteLinkResponse>")
                    return inviteData.inviteLink
                }
                
                // If both methods fail, try to decode just the GenerateInviteLinkResponse
                if let directResponse = try? JSONDecoder().decode(GenerateInviteLinkResponse.self, from: data) {
                    print("Successfully decoded GenerateInviteLinkResponse directly")
                    return directResponse.inviteLink
                }
                
                // If all decoding attempts fail, throw an error
                throw EventDetailError.apiError("Failed to parse invite link from response")
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to generate invite link")
            }
        } catch {
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error generating invite link: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update event details
    func updateEvent(eventId: Int, updateRequest: UpdateEventRequest) async -> (Bool, EventResponse?) {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/{id} endpoint with PUT method
            guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
                throw EventDetailError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(updateRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventDetailError.invalidResponse
            }
            
            // For debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Update Event Response JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                // Try to decode the updated event
                if let updatedEventResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
                   let updatedEvent = updatedEventResponse.data {
                    return (true, updatedEvent)
                }
                return (true, nil)
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse.error ?? "Failed to update event")
            }
        } catch {
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error updating event: \(error.localizedDescription)")
            return (false, nil)
        }
    }
    
    // Check if the user is a participant of the event
    func checkEventAccess(eventId: Int) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            // Using /events/{id} endpoint to check access
            guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
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
            print("Event Access Check Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Event Access Check JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                hasAccess = true
                
                // Check if the current user is the event owner
                if let eventResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
                   let event = eventResponse.data {
                    // Get the current user ID from KeychainManager or UserDefaults
                    if let userId = await KeychainManager.shared.getUserId() {
                        isOwner = (event.organizerId == userId)
                    }
                }
                
                return true
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Handle authorization errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.error ?? "You are not a participant of this event"
                hasAccess = false
                isOwner = false
                throw EventDetailError.apiError(errorMessage)
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                hasAccess = false
                isOwner = false
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to check event access")
            }
        } catch {
            showError = true
            hasAccess = false
            isOwner = false
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error checking event access: \(error.localizedDescription)")
            return false
        }
    }
    
    // Generate and copy invite link to clipboard
    func generateAndCopyInviteLink(eventId: Int) async {
        print("Generating invite link for event ID: \(eventId)")
        
        do {
            guard let inviteLink = await generateInviteLink(eventId: eventId) else {
                throw EventDetailError.apiError("Failed to generate invite link")
            }
            
            print("Successfully generated invite link: \(inviteLink)")
            
            // Copy to clipboard on the main thread
            DispatchQueue.main.async {
                UIPasteboard.general.string = inviteLink
                print("Copied link to clipboard: \(inviteLink)")
                
                // Show notification
                self.showShareLinkCopied = true
                print("Set showShareLinkCopied to true")
                
                // Hide notification after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showShareLinkCopied = false
                    print("Set showShareLinkCopied to false")
                }
            }
        } catch {
            print("Error generating invite link: \(error.localizedDescription)")
            
            // Show error on the main thread
            DispatchQueue.main.async {
                self.showError = true
                if let eventError = error as? EventDetailError {
                    self.errorMessage = eventError.message
                } else {
                    self.errorMessage = "Не удалось создать ссылку-приглашение"
                }
            }
        }
    }
    
    // Start editing event name
    func startEditingName(currentName: String) {
        editedName = currentName
        isEditingName = true
    }
    
    // Start editing event description
    func startEditingDescription(currentDescription: String?) {
        editedDescription = currentDescription ?? ""
        isEditingDescription = true
    }
    
    // Start editing event date and time
    func startEditingDateTime(currentDateTime: String) {
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: currentDateTime) {
            editedDateTime = date
        } else {
            editedDateTime = Date()
        }
        isEditingDateTime = true
    }
    
    // Start editing event place
    func startEditingPlace(currentPlace: String?) {
        editedPlace = currentPlace ?? ""
        isEditingPlace = true
    }
    
    // Start editing event budget
    func startEditingBudget(currentBudget: Double) {
        editedBudget = String(format: "%.0f", currentBudget)
        isEditingBudget = true
    }
    
    // Save event edits
    func saveEventEdits(eventId: Int) async -> (Bool, EventResponse?) {
        // Create update request with only the fields that were edited
        let updateRequest = UpdateEventRequest(
            name: isEditingName ? editedName : nil,
            description: isEditingDescription ? editedDescription : nil,
            eventDateTime: isEditingDateTime ? ISO8601DateFormatter().string(from: editedDateTime) : nil,
            place: isEditingPlace ? editedPlace : nil,
            budget: isEditingBudget ? Double(editedBudget) : nil
        )
        
        // Reset edit modes
        isEditingName = false
        isEditingDescription = false
        isEditingDateTime = false
        isEditingPlace = false
        isEditingBudget = false
        
        // Update the event
        return await updateEvent(eventId: eventId, updateRequest: updateRequest)
    }
    
    // Cancel editing
    func cancelEditing() {
        isEditingName = false
        isEditingDescription = false
        isEditingDateTime = false
        isEditingPlace = false
        isEditingBudget = false
    }
    
    // Helper method to print JSON data for debugging
    private func printJSON(_ data: Data, label: String) {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("\(label):\n\(prettyString)")
        } else if let string = String(data: data, encoding: .utf8) {
            print("\(label) (raw):\n\(string)")
        }
    }
} 