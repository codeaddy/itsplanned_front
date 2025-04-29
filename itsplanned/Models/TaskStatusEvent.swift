import Foundation

struct TaskStatusEvent: Identifiable, Codable {
    let id: Int
    let taskId: Int
    let taskName: String
    let oldStatus: String
    let newStatus: String
    let changedById: Int
    let changedByName: String
    let isRead: Bool
    let eventTime: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case taskName = "task_name"
        case oldStatus = "old_status"
        case newStatus = "new_status"
        case changedById = "changed_by_id"
        case changedByName = "changed_by_name"
        case isRead = "is_read"
        case eventTime = "event_time"
    }
}

struct TaskStatusEventsResponse: Codable {
    let events: [TaskStatusEvent]
}

extension TaskStatusEvent {
    var notificationTitle: String {
        switch newStatus {
        case "unassigned":
            return "Задача без исполнителя"
        case "assigned":
            return "Задача назначена"
        case "completed":
            return "Задача выполнена"
        default:
            return "Изменение статуса задачи"
        }
    }
    
    var notificationBody: String {
        switch newStatus {
        case "unassigned":
            return "Задача \"\(taskName)\" осталась без исполнителя"
        case "assigned":
            return "\(changedByName) стал исполнителем задачи \"\(taskName)\""
        case "completed":
            return "\(changedByName) выполнил задачу \"\(taskName)\""
        default:
            return "Статус задачи \"\(taskName)\" был изменен"
        }
    }
} 
