import Foundation

struct EventResponse: Codable, Equatable {
    let id: Int
    let createdAt: String
    let updatedAt: String
    let name: String
    let description: String?
    let eventDateTime: String
    let place: String?
    let initialBudget: Double
    let organizerId: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case name
        case description
        case eventDateTime = "event_date_time"
        case place
        case initialBudget = "initial_budget"
        case organizerId = "organizer_id"
    }
    
    static func == (lhs: EventResponse, rhs: EventResponse) -> Bool {
        return lhs.id == rhs.id &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.eventDateTime == rhs.eventDateTime &&
               lhs.place == rhs.place &&
               lhs.initialBudget == rhs.initialBudget &&
               lhs.organizerId == rhs.organizerId
    }
}

struct CreateEventRequest: Codable {
    let name: String
    let description: String?
    let eventDateTime: String
    let place: String?
    let initialBudget: Double?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case eventDateTime = "event_date_time"
        case place
        case initialBudget = "initial_budget"
    }
}

struct UpdateEventRequest: Codable {
    let name: String?
    let description: String?
    let eventDateTime: String?
    let place: String?
    let budget: Double?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case eventDateTime = "event_date_time"
        case place
        case budget
    }
}

struct EventBudgetResponse: Codable {
    let initialBudget: Double
    let realBudget: Double
    let difference: Double
    
    enum CodingKeys: String, CodingKey {
        case initialBudget = "initial_budget"
        case realBudget = "real_budget"
        case difference
    }
}

struct EventLeaderboardEntry: Codable {
    let userId: Int
    let score: Double
    let eventId: Int
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case score
        case eventId = "event_id"
        case displayName = "display_name"
    }
} 