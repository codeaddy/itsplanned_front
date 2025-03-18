import Foundation

// Updated model to match the server response structure
struct EventLeaderboardResponse: Codable {
    let leaderboard: [EventLeaderboardEntry]
    
    // Allow for direct decoding if the server sends the leaderboard array directly
    init(from decoder: Decoder) throws {
        do {
            // First try to decode the standard way
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.leaderboard = try container.decode([EventLeaderboardEntry].self, forKey: .leaderboard)
        } catch {
            // If that fails, try to decode as a direct array
            self.leaderboard = try [EventLeaderboardEntry].init(from: decoder)
        }
    }
    
    // For encoding, always use the standard format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leaderboard, forKey: .leaderboard)
    }
    
    enum CodingKeys: String, CodingKey {
        case leaderboard
    }
} 