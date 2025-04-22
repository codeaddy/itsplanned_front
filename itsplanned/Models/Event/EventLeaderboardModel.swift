import Foundation

struct EventLeaderboardResponse: Codable {
    let leaderboard: [EventLeaderboardEntry]
    
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.leaderboard = try container.decode([EventLeaderboardEntry].self, forKey: .leaderboard)
        } catch {
            self.leaderboard = try [EventLeaderboardEntry].init(from: decoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leaderboard, forKey: .leaderboard)
    }
    
    enum CodingKeys: String, CodingKey {
        case leaderboard
    }
} 