import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.itsplanned", category: "EventDetails")

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
    @Published var showingTimeslotsView: Bool = false
    
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
    
    func fetchParticipants(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
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
            
            print("Participants API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Participants JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                let participantsResponse = try JSONDecoder().decode(EventParticipantsResponse.self, from: data)
                self.participants = participantsResponse.participants
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
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
    
    func fetchBudgetInfo(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
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
    
    func fetchLeaderboard(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
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
    
    func generateInviteLink(eventId: Int) async -> String? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
            guard let url = URL(string: "\(baseURL)/events/invite") else {
                throw EventDetailError.invalidURL
            }
            
            let inviteRequest = GenerateInviteLinkRequest(eventId: eventId)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(inviteRequest)
            
            if let requestBody = request.httpBody {
                printJSON(requestBody, label: "Invite Link Request")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventDetailError.invalidResponse
            }
            
            print("Invite Link Response Status: \(httpResponse.statusCode)")
            printJSON(data, label: "Invite Link Response")
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let inviteLink = json["invite_link"] as? String {
                    print("Successfully extracted invite_link from JSON dictionary")
                    return inviteLink
                }
                
                if let inviteResponse = try? JSONDecoder().decode(APIResponse<GenerateInviteLinkResponse>.self, from: data),
                   let inviteData = inviteResponse.data {
                    print("Successfully decoded APIResponse<GenerateInviteLinkResponse>")
                    return inviteData.inviteLink
                }
                
                if let directResponse = try? JSONDecoder().decode(GenerateInviteLinkResponse.self, from: data) {
                    print("Successfully decoded GenerateInviteLinkResponse directly")
                    return directResponse.inviteLink
                }
                
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
    
    func updateEvent(eventId: Int, updateRequest: UpdateEventRequest) async -> (Bool, EventResponse?) {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw EventDetailError.unauthorized
            }
            
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
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Update Event Response JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
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
            
            print("Event Access Check Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Event Access Check JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                hasAccess = true
                
                if let eventResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
                   let event = eventResponse.data {
                    if let userId = await KeychainManager.shared.getUserId() {
                        isOwner = (event.organizerId == userId)
                    }
                }
                
                return true
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
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
    
    func generateAndCopyInviteLink(eventId: Int) async {
        print("Generating invite link for event ID: \(eventId)")
        
        do {
            guard let inviteLink = await generateInviteLink(eventId: eventId) else {
                throw EventDetailError.apiError("Failed to generate invite link")
            }
            
            print("Successfully generated invite link: \(inviteLink)")
            
            DispatchQueue.main.async {
                UIPasteboard.general.string = inviteLink
                print("Copied link to clipboard: \(inviteLink)")
                
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
    
    func startEditingName(currentName: String) {
        editedName = currentName
        isEditingName = true
    }
    
    func startEditingDescription(currentDescription: String?) {
        editedDescription = currentDescription ?? ""
        isEditingDescription = true
    }
    
    func startEditingDateTime(currentDateTime: String) {
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: currentDateTime) {
            editedDateTime = date
        } else {
            editedDateTime = Date()
        }
        isEditingDateTime = true
    }
    
    func startEditingPlace(currentPlace: String?) {
        editedPlace = currentPlace ?? ""
        isEditingPlace = true
    }
    
    func startEditingBudget(currentBudget: Double) {
        editedBudget = String(format: "%.0f", currentBudget)
        isEditingBudget = true
    }
    
    func saveEventEdits(eventId: Int) async -> (Bool, EventResponse?) {
        let updateRequest = UpdateEventRequest(
            name: isEditingName ? editedName : nil,
            description: isEditingDescription ? editedDescription : nil,
            eventDateTime: isEditingDateTime ? ISO8601DateFormatter().string(from: editedDateTime) : nil,
            place: isEditingPlace ? editedPlace : nil,
            budget: isEditingBudget ? Double(editedBudget) : nil
        )
        
        isEditingName = false
        isEditingDescription = false
        isEditingDateTime = false
        isEditingPlace = false
        isEditingBudget = false
        
        return await updateEvent(eventId: eventId, updateRequest: updateRequest)
    }
    
    func cancelEditing() {
        isEditingName = false
        isEditingDescription = false
        isEditingDateTime = false
        isEditingPlace = false
        isEditingBudget = false
    }
    
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
