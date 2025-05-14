import Foundation

struct TimeslotSuggestion: Identifiable, Codable {
    let slot: String
    let busyCount: Int
    
    var id: String {
        slot
    }
    
    enum CodingKeys: String, CodingKey {
        case slot
        case busyCount = "busy_count"
    }
    
    func formattedTime() -> String {
        if let spaceIndex = slot.firstIndex(of: " ") {
            let timeComponent = String(slot[slot.index(after: spaceIndex)...])
            return timeComponent
        }
        return slot
    }
}

struct FindBestTimeSlotsRequest: Codable {
    let eventId: Int
    let date: String
    let durationMins: Int
    let startTime: String?
    let endTime: String?
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case date
        case durationMins = "duration_mins"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct FindBestTimeSlotsResponse: Codable {
    let suggestions: [TimeslotSuggestion]
} 