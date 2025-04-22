import Foundation

struct GenerateInviteLinkRequest: Codable {
    let eventId: Int
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
    }
}

struct GenerateInviteLinkResponse: Codable {
    let inviteLink: String
    
    enum CodingKeys: String, CodingKey {
        case inviteLink = "invite_link"
    }
} 