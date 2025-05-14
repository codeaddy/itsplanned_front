import Foundation

struct JoinEventResponse: Codable {
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case message
    }
} 