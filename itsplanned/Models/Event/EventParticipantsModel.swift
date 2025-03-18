import Foundation

struct EventParticipantsResponse: Codable {
    let participants: [String]
    
    enum CodingKeys: String, CodingKey {
        case participants
    }
} 