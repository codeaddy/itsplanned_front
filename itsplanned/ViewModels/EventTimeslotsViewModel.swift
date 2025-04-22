import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "EventTimeslots")

enum TimeslotError: Error {
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
class EventTimeslotsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var timeslots: [TimeslotSuggestion] = []
    @Published var selectedTimeslot: TimeslotSuggestion?
    @Published var date = Date()
    @Published var startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var endTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var durationMins: Int = 120 // Default duration of 2 hours
    
    private let baseURL = "http://localhost:8080"
    
    // Fetch available timeslots for the given event and date
    func fetchTimeslots(eventId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TimeslotError.unauthorized
            }
            
            // Format the date for the API request
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Format the start and end times
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let startTimeString = timeFormatter.string(from: startTime)
            let endTimeString = timeFormatter.string(from: endTime)
            
            guard let url = URL(string: "\(baseURL)/events/find_best_time_for_day") else {
                throw TimeslotError.invalidURL
            }
            
            // Create the request body
            let timeslotRequest = FindBestTimeSlotsRequest(
                eventId: eventId,
                date: dateString,
                durationMins: durationMins,
                startTime: startTimeString,
                endTime: endTimeString
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(timeslotRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TimeslotError.invalidResponse
            }
            
            // For debugging - print full response details
            logger.debug("Timeslots API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Timeslots JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                // Try to decode using the APIResponse wrapper first
                let apiResponse = try JSONDecoder().decode(APIResponse<FindBestTimeSlotsResponse>.self, from: data)
                if let responseData = apiResponse.data {
                    self.timeslots = responseData.suggestions.sorted { $0.busyCount < $1.busyCount }
                } else if let errorMessage = apiResponse.error {
                    throw TimeslotError.apiError(errorMessage)
                } else {
                    // Try direct decoding
                    let directResponse = try JSONDecoder().decode(FindBestTimeSlotsResponse.self, from: data)
                    self.timeslots = directResponse.suggestions.sorted { $0.busyCount < $1.busyCount }
                }
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                // Handle authorization errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                let errorMessage = errorResponse?.error ?? "You are not authorized to view this event's timeslots"
                throw TimeslotError.apiError(errorMessage)
            } else {
                // Handle other errors
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw TimeslotError.apiError(errorResponse?.error ?? "Failed to fetch timeslots")
            }
        } catch {
            showError = true
            if let timeslotError = error as? TimeslotError {
                errorMessage = timeslotError.message
            } else {
                errorMessage = error.localizedDescription
            }
            logger.error("Error fetching timeslots: \(error.localizedDescription)")
        }
    }
    
    // Update the event with the selected timeslot
    func updateEventTime(eventId: Int) async -> (Bool, EventResponse?) {
        guard let selectedTimeslot = selectedTimeslot else {
            errorMessage = "No timeslot selected"
            showError = true
            return (false, nil)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TimeslotError.unauthorized
            }
            
            guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
                throw TimeslotError.invalidURL
            }
            
            // Logging for debugging
            logger.debug("Selected timeslot: \(selectedTimeslot.slot)")
            
            // Parse the selected timeslot to create a Date
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            
            guard let selectedDate = inputFormatter.date(from: selectedTimeslot.slot) else {
                logger.error("Failed to parse date from: \(selectedTimeslot.slot)")
                throw TimeslotError.apiError("Invalid date format")
            }
            
            // Convert to ISO 8601 format
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            let isoDateString = iso8601Formatter.string(from: selectedDate)
            
            logger.debug("Converted ISO date: \(isoDateString)")
            
            // Create the update request
            let updateRequest = UpdateEventRequest(
                name: nil,
                description: nil,
                eventDateTime: isoDateString,
                place: nil,
                budget: nil
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            // Log the request body for debugging
            let jsonData = try JSONEncoder().encode(updateRequest)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("Update request body: \(jsonString)")
            }
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Update response: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TimeslotError.invalidResponse
            }
            
            logger.debug("Update response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Try different decoding approaches
                do {
                    // First try: parse with APIResponse wrapper
                    let eventResponse = try JSONDecoder().decode(APIResponse<EventResponse>.self, from: data)
                    if let updatedEvent = eventResponse.data {
                        return (true, updatedEvent)
                    } else if let errorMsg = eventResponse.error {
                        throw TimeslotError.apiError(errorMsg)
                    }
                } catch {
                    logger.error("First decoding attempt failed: \(error.localizedDescription)")
                    
                    // Second try: direct decoding of EventResponse
                    do {
                        let directEvent = try JSONDecoder().decode(EventResponse.self, from: data)
                        return (true, directEvent)
                    } catch {
                        logger.error("Second decoding attempt failed: \(error.localizedDescription)")
                        throw TimeslotError.apiError("Could not parse updated event data")
                    }
                }
            } else {
                // Handle API errors
                do {
                    let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                    let errorMsg = errorResponse.error ?? errorResponse.message ?? "Failed to update event time"
                    throw TimeslotError.apiError(errorMsg)
                } catch {
                    // If can't decode the error response
                    if let responseText = String(data: data, encoding: .utf8) {
                        throw TimeslotError.apiError("Server error: \(responseText)")
                    } else {
                        throw TimeslotError.apiError("Failed to update event time (Status: \(httpResponse.statusCode))")
                    }
                }
            }
            
            // If we get here, something unexpected happened
            throw TimeslotError.apiError("Unexpected error updating event time")
        } catch {
            showError = true
            if let timeslotError = error as? TimeslotError {
                errorMessage = timeslotError.message
            } else {
                errorMessage = "Failed to update event time: \(error.localizedDescription)"
            }
            logger.error("Error updating event time: \(error.localizedDescription)")
            return (false, nil)
        }
    }
    
    // Change the date and fetch new timeslots
    func changeDate(to newDate: Date, eventId: Int) async {
        self.date = newDate
        await fetchTimeslots(eventId: eventId)
    }
} 