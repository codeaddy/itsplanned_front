import Foundation
import SwiftUI

struct LeaderboardUser: Identifiable, Equatable {
    let id: Int
    let userId: Int
    let displayName: String
    let score: Double
    let position: Int
    let avatar: String?
    
    static func == (lhs: LeaderboardUser, rhs: LeaderboardUser) -> Bool {
        return lhs.id == rhs.id && 
               lhs.userId == rhs.userId &&
               lhs.displayName == rhs.displayName &&
               lhs.score == rhs.score &&
               lhs.position == rhs.position &&
               lhs.avatar == rhs.avatar
    }
}

@MainActor
class EventLeaderboardViewModel: ObservableObject {
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var currentUserPosition: Int = 0
    @Published var currentUserEntry: LeaderboardUser?
    
    private let baseURL = "http://localhost:8080"
    
    // Fetch leaderboard data and transform it to include user information
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
                // Try multiple decoding approaches to handle different response formats
                var leaderboardEntries: [EventLeaderboardEntry] = []
                
                // First try direct approach with EventLeaderboardResponse
                do {
                    let leaderboardData = try JSONDecoder().decode(EventLeaderboardResponse.self, from: data)
                    leaderboardEntries = leaderboardData.leaderboard
                    print("✅ Decoded using EventLeaderboardResponse: \(leaderboardEntries.count) entries")
                } catch let error1 {
                    print("❓ EventLeaderboardResponse decode failed: \(error1)")
                    
                    // Try with APIResponse wrapper
                    do {
                        let apiResponse = try JSONDecoder().decode(APIResponse<EventLeaderboardResponse>.self, from: data)
                        if let responseData = apiResponse.data {
                            leaderboardEntries = responseData.leaderboard
                            print("✅ Decoded using APIResponse<EventLeaderboardResponse>: \(leaderboardEntries.count) entries")
                        } else {
                            print("❌ APIResponse.data is nil")
                        }
                    } catch let error2 {
                        print("❓ APIResponse<EventLeaderboardResponse> decode failed: \(error2)")
                        
                        // Try direct array
                        do {
                            leaderboardEntries = try JSONDecoder().decode([EventLeaderboardEntry].self, from: data)
                            print("✅ Decoded as direct [EventLeaderboardEntry]: \(leaderboardEntries.count) entries")
                        } catch let error3 {
                            print("❓ [EventLeaderboardEntry] decode failed: \(error3)")
                            
                            // One more attempt: try decoding the root object and extracting the leaderboard
                            do {
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let leaderboardArray = json["leaderboard"] as? [[String: Any]] {
                                    print("✅ Found leaderboard array with \(leaderboardArray.count) entries using JSONSerialization")
                                    
                                    // Manually create entries from the dictionary
                                    for (index, entry) in leaderboardArray.enumerated() {
                                        if let userId = entry["user_id"] as? Int,
                                           let score = entry["score"] as? Double,
                                           let eventId = entry["event_id"] as? Int {
                                            
                                            let leaderboardEntry = EventLeaderboardEntry(
                                                userId: userId,
                                                score: score,
                                                eventId: eventId
                                            )
                                            leaderboardEntries.append(leaderboardEntry)
                                            print("✅ Manually added entry \(index): userId=\(userId), score=\(score)")
                                        }
                                    }
                                } else {
                                    print("❌ Could not extract leaderboard array using JSONSerialization")
                                }
                            } catch let error4 {
                                print("❌ JSONSerialization failed: \(error4)")
                                throw EventDetailError.apiError("Could not parse leaderboard data: \(error1.localizedDescription)")
                            }
                        }
                    }
                }
                
                // Process the entries if we have any
                if !leaderboardEntries.isEmpty {
                    print("✅ Successfully extracted \(leaderboardEntries.count) leaderboard entries")
                    await processLeaderboardEntries(leaderboardEntries, eventId: eventId)
                } else {
                    print("⚠️ No leaderboard entries found after all decoding attempts")
                    await MainActor.run {
                        self.leaderboardUsers = []
                    }
                }
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "You are not authorized to view this event's leaderboard")
            } else {
                let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw EventDetailError.apiError(errorResponse?.error ?? "Failed to fetch leaderboard")
            }
        } catch {
            print("❌ Error fetching leaderboard: \(error.localizedDescription)")
            showError = true
            if let eventError = error as? EventDetailError {
                errorMessage = eventError.message
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // Process leaderboard entries to get user information for each entry
    private func processLeaderboardEntries(_ entries: [EventLeaderboardEntry], eventId: Int) async {
        print("🔄 Processing \(entries.count) leaderboard entries")
        
        // Early return if no entries
        if entries.isEmpty {
            await MainActor.run {
                self.leaderboardUsers = []
                print("⚠️ No entries to process, set leaderboardUsers to empty array")
            }
            return
        }
        
        // Sort entries by score in descending order
        let sortedEntries = entries.sorted(by: { $0.score > $1.score })
        print("📊 Sorted entries: \(sortedEntries)")
        
        var processedUsers: [LeaderboardUser] = []
        let currentUserId = await KeychainManager.shared.getUserId() ?? 0
        print("👤 Current user ID: \(currentUserId)")
        
        // Get user details for each entry
        for (index, entry) in sortedEntries.enumerated() {
            let position = index + 1
            print("📝 Processing entry \(index): userId=\(entry.userId), score=\(entry.score), position=\(position)")
            
            // Get user details from the database or API
            if let userDetails = await fetchUserDetails(for: entry.userId) {
                print("✅ User details found for user \(entry.userId): \(userDetails.displayName)")
                let leaderboardUser = LeaderboardUser(
                    id: index,
                    userId: entry.userId,
                    displayName: userDetails.displayName,
                    score: entry.score,
                    position: position,
                    avatar: userDetails.avatar
                )
                
                processedUsers.append(leaderboardUser)
                
                // Check if this is the current user
                if entry.userId == currentUserId {
                    print("🎯 Current user found at position \(position)")
                    currentUserPosition = position
                    currentUserEntry = leaderboardUser
                }
            } else {
                // If user details not available, use placeholder with user ID
                print("⚠️ No user details found for user \(entry.userId), using placeholder")
                let leaderboardUser = LeaderboardUser(
                    id: index,
                    userId: entry.userId,
                    displayName: "Пользователь #\(entry.userId)",
                    score: entry.score,
                    position: position,
                    avatar: nil
                )
                
                processedUsers.append(leaderboardUser)
                
                // Check if this is the current user
                if entry.userId == currentUserId {
                    print("🎯 Current user found at position \(position) (using placeholder)")
                    currentUserPosition = position
                    currentUserEntry = leaderboardUser
                }
            }
        }
        
        print("✅ Final processed users count: \(processedUsers.count)")
        await MainActor.run {
            self.leaderboardUsers = processedUsers
            print("📱 Updated leaderboardUsers on UI: \(self.leaderboardUsers.count) items")
        }
    }
    
    // Fetch user details for a given user ID
    private func fetchUserDetails(for userId: Int) async -> UserResponse? {
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                return nil
            }
            
            guard let url = URL(string: "\(baseURL)/users/\(userId)") else {
                return nil
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }
            
            print("User API Response Status for ID \(userId): \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    // Try to decode the actual user response from the API
                    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                    print("✅ Successfully decoded user data for ID \(userId): \(userResponse.displayName)")
                    return userResponse
                } catch {
                    print("❌ Failed to decode user data: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("User JSON: \(jsonString)")
                    }
                }
            }
            
            // If we can't get the user data from the API, return a basic user object with the ID
            print("⚠️ Using default display name for user ID \(userId)")
            return UserResponse(
                id: userId,
                email: "user\(userId)@example.com",
                displayName: "Пользователь #\(userId)",
                bio: nil,
                avatar: nil,
                createdAt: "2023-01-01T00:00:00Z",
                updatedAt: "2023-01-01T00:00:00Z"
            )
        } catch {
            print("Error fetching user details for ID \(userId): \(error.localizedDescription)")
            return nil
        }
    }
} 