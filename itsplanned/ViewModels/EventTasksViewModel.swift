import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "EventTasks")

@MainActor
final class EventTasksViewModel: ObservableObject {
    @Published var tasks: [TaskResponse] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var newTaskTitle = ""
    @Published var isAddingTask = false
    @Published var isEventCreator = false
    
    private let baseURL = "http://localhost:8080"
    private var currentUserId: Int?
    private var isPreviewMode = false
    
    // Set current user ID (useful for previews)
    func setCurrentUserId(_ id: Int) {
        currentUserId = id
    }
    
    // Skip API calls for preview mode
    func skipAPICallsForPreview() {
        isPreviewMode = true
    }
    
    // Set event creator status (useful for previews and testing)
    func setIsEventCreator(_ isCreator: Bool) {
        isEventCreator = isCreator
    }
    
    // Fetch tasks for a specific event
    func fetchTasks(eventId: Int) async {
        // Skip API call in preview mode
        if isPreviewMode {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            // Get current user ID
            currentUserId = await KeychainManager.shared.getUserId()
            
            // First, check if the current user is the event creator
            await checkIfEventCreator(eventId: eventId)
            
            // Use the correct endpoint with query parameter for event_id
            guard let url = URL(string: "\(baseURL)/tasks?event_id=\(eventId)") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            // For debugging - print full response details
            logger.debug("Tasks API Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Tasks JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                let tasksResponse = try JSONDecoder().decode(APIResponse<[TaskResponse]>.self, from: data)
                if let eventTasks = tasksResponse.data {
                    self.tasks = eventTasks
                    
                    if self.tasks.isEmpty {
                        logger.debug("No tasks found for event ID: \(eventId)")
                    } else {
                        logger.debug("Found \(self.tasks.count) tasks for event ID: \(eventId)")
                    }
                } else {
                    logger.debug("Received empty data array from tasks API")
                    self.tasks = []
                }
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to fetch tasks (code: \(httpResponse.statusCode))")
                } else {
                    throw TaskError.apiError("Failed to fetch tasks: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error fetching tasks: \(error.localizedDescription)")
        }
    }
    
    // Check if current user is the event creator
    private func checkIfEventCreator(eventId: Int) async {
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let eventResponse = try JSONDecoder().decode(APIResponse<EventResponse>.self, from: data)
                if let event = eventResponse.data {
                    // Check if current user is the event creator
                    self.isEventCreator = event.organizerId == currentUserId
                    logger.debug("Current user is \(self.isEventCreator ? "" : "not ")the event creator")
                }
            } else {
                logger.debug("Failed to get event details: HTTP \(httpResponse.statusCode)")
                self.isEventCreator = false
            }
        } catch {
            logger.error("Error checking if user is event creator: \(error.localizedDescription)")
            self.isEventCreator = false
        }
    }
    
    // Update task details (title, description, budget, points)
    func updateTask(taskId: Int, title: String, description: String?, budget: Double?, points: Int?) async -> Bool {
        // In preview mode, update the task directly
        if isPreviewMode {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                let task = tasks[index]
                
                // Create an updated task
                let updatedTask = TaskResponse(
                    id: task.id,
                    title: title,
                    description: description,
                    budget: budget,
                    points: points ?? task.points,
                    eventId: task.eventId,
                    assignedTo: task.assignedTo,
                    isCompleted: task.isCompleted
                )
                tasks[index] = updatedTask
            }
            return true
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(baseURL)/tasks/\(taskId)") else {
                throw TaskError.invalidURL
            }
            
            // Create request body with same structure as CreateTaskRequest
            struct UpdateTaskRequest: Codable {
                let title: String
                let description: String?
                let budget: Double?
                let points: Int?
                
                // CodingKeys to match the API's expected field names
                enum CodingKeys: String, CodingKey {
                    case title = "title"
                    case description = "description"
                    case budget = "budget"
                    case points = "points"
                }
            }
            
            let updateRequest = UpdateTaskRequest(
                title: title,
                description: description,
                budget: budget,
                points: points
            )
            
            // Log the request body for debugging
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let requestData = try? encoder.encode(updateRequest),
               let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("Update task request body: \(requestString)")
                print("Update task request body: \(requestString)") // Added for console visibility
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updateRequest)
            
            // Log full request details
            print("Update task URL: \(url)")
            print("Update task method: \(request.httpMethod ?? "unknown")")
            print("Update task headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            // Log the response for debugging
            logger.debug("Update task response status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Update task response: \(jsonString)")
                print("Update task response: \(jsonString)") // Added for console visibility
            }
            
            if httpResponse.statusCode == 200 {
                // Update was successful, refresh tasks to get updated data
                if let task = tasks.first(where: { $0.id == taskId }) {
                    // Just update the values locally first for immediate feedback
                    if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                        // Create a new task object with updated values instead of modifying the existing one
                        let updatedTask = TaskResponse(
                            id: task.id,
                            title: title,
                            description: description,
                            budget: budget,
                            points: points ?? task.points,
                            eventId: task.eventId,
                            assignedTo: task.assignedTo,
                            isCompleted: task.isCompleted
                        )
                        tasks[index] = updatedTask
                    }
                    
                    // Then refresh from server
                    await fetchTasks(eventId: task.eventId)
                }
                return true
            } else {
                // Try to get error details
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to update task")
                } else {
                    throw TaskError.apiError("Failed to update task: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error updating task: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // Create a new task
    func createTask(eventId: Int) async -> Bool {
        // In preview mode, create a mock task
        if isPreviewMode {
            let newId = (tasks.map { $0.id }.max() ?? 0) + 1
            let newTask = TaskResponse(
                id: newId,
                title: newTaskTitle,
                description: nil,
                budget: nil,
                points: 5,
                eventId: eventId,
                assignedTo: nil,
                isCompleted: false
            )
            tasks.append(newTask)
            newTaskTitle = ""
            isAddingTask = false
            return true
        }
        
        guard !newTaskTitle.isEmpty else { return false }
        
        isLoading = true
        defer { 
            isLoading = false
            isAddingTask = false
        }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(baseURL)/tasks") else {
                throw TaskError.invalidURL
            }
            
            // Default points value for new tasks
            let points = 5
            
            let createTaskRequest = CreateTaskRequest(
                title: newTaskTitle,
                description: nil,
                budget: nil,
                points: points,
                eventId: eventId,
                assignedTo: nil
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(createTaskRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let taskResponse = try JSONDecoder().decode(APIResponse<TaskResponse>.self, from: data)
                if let newTask = taskResponse.data {
                    self.tasks.append(newTask)
                    self.newTaskTitle = ""
                    
                    // Refresh the task list to ensure everything is up to date
                    await fetchTasks(eventId: eventId)
                    return true
                }
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw TaskError.apiError(errorResponse.error ?? "Failed to create task")
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error creating task: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // Toggle task assignment (assign or unassign the current user)
    func toggleTaskAssignment(taskId: Int) async {
        // In preview mode, update the task directly
        if isPreviewMode {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                let task = tasks[index]
                let isCurrentUserAlreadyAssigned = task.assignedTo == currentUserId
                
                // Create a new task with toggled assignedTo
                let updatedTask = TaskResponse(
                    id: task.id,
                    title: task.title,
                    description: task.description,
                    budget: task.budget,
                    points: task.points,
                    eventId: task.eventId,
                    assignedTo: isCurrentUserAlreadyAssigned ? nil : currentUserId,
                    isCompleted: task.isCompleted
                )
                tasks[index] = updatedTask
            }
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            // The /tasks/{id}/assign endpoint now toggles assignment (assign or unassign)
            guard let url = URL(string: "\(baseURL)/tasks/\(taskId)/assign") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let taskResponse = try JSONDecoder().decode(APIResponse<TaskResponse>.self, from: data)
                if let updatedTask = taskResponse.data {
                    // Update the task in the tasks array
                    if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                        tasks[index] = updatedTask
                    }
                    
                    // Refresh the task list to ensure everything is up to date
                    let eventId = updatedTask.eventId
                    await fetchTasks(eventId: eventId)
                }
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task assignment")
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error toggling task assignment: \(error.localizedDescription)")
        }
    }
    
    // Toggle task completion status
    func toggleTaskCompletion(taskId: Int) async {
        // In preview mode, update the task directly
        if isPreviewMode {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                let task = tasks[index]
                
                // Create a new task with toggled isCompleted
                let updatedTask = TaskResponse(
                    id: task.id,
                    title: task.title,
                    description: task.description,
                    budget: task.budget,
                    points: task.points,
                    eventId: task.eventId,
                    assignedTo: task.assignedTo,
                    isCompleted: !task.isCompleted
                )
                tasks[index] = updatedTask
            }
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            // The /tasks/{id}/complete endpoint now toggles completion (complete or uncomplete)
            guard let url = URL(string: "\(baseURL)/tasks/\(taskId)/complete") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let taskResponse = try JSONDecoder().decode(APIResponse<TaskResponse>.self, from: data)
                if let updatedTask = taskResponse.data {
                    // Update the task in the tasks array
                    if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                        tasks[index] = updatedTask
                    }
                    
                    // Refresh the task list to ensure everything is up to date
                    let eventId = updatedTask.eventId
                    await fetchTasks(eventId: eventId)
                }
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task completion")
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error toggling task completion: \(error.localizedDescription)")
        }
    }
    
    // Check if the current user is assigned to a task
    func isCurrentUserAssigned(to task: TaskResponse) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        return task.assignedTo == currentUserId
    }
    
    // Start adding a new task
    func startAddingTask() {
        isAddingTask = true
        newTaskTitle = ""
    }
    
    // Cancel adding a new task
    func cancelAddingTask() {
        isAddingTask = false
        newTaskTitle = ""
    }
}

enum TaskError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case apiError(String)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized"
        case .apiError(let message):
            return message
        }
    }
} 