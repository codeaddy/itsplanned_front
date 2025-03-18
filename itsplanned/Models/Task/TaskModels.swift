import Foundation

struct TaskResponse: Codable {
    let id: Int
    let title: String
    let description: String?
    let budget: Double?
    let points: Int
    let eventId: Int
    let assignedTo: Int?
    let isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case budget
        case points
        case eventId = "event_id"
        case assignedTo = "assigned_to"
        case isCompleted = "is_completed"
    }
}

struct CreateTaskRequest: Codable {
    let title: String
    let description: String?
    let budget: Double?
    let points: Int
    let eventId: Int
    let assignedTo: Int?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case budget
        case points
        case eventId = "event_id"
        case assignedTo = "assigned_to"
    }
} 