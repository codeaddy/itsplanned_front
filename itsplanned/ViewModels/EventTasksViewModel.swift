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
    func fetchTasks(eventId: Int) async throws {
        guard !isPreviewMode else { 
            print("Preview mode: skipping API call")
            return 
        }
        
        print("🔍 Fetching tasks for event ID: \(eventId)")
        
        // Set loading state at the beginning
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Always reset loading state when done
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        // Get current user ID and check event creator status
        await checkIfEventCreator(eventId: eventId)
        
        // Get auth token
        guard let token = await KeychainManager.shared.getToken() else {
            print("❌ No auth token available")
            throw TaskError.unauthorized
        }
        
        // Build URL with query parameters
        guard var urlComponents = URLComponents(string: "\(baseURL)/tasks") else {
            print("❌ Invalid URL components")
            throw TaskError.invalidURL
        }
        
        // Add the event_id query parameter
        urlComponents.queryItems = [
            URLQueryItem(name: "event_id", value: String(eventId))
        ]
        
        guard let url = urlComponents.url else {
            print("❌ Failed to construct URL with query parameters")
            throw TaskError.invalidURL
        }
        
        print("🌐 Making request to: \(url.absoluteString)")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Make network request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw TaskError.invalidResponse
        }
        
        print("📊 Response status code: \(httpResponse.statusCode)")
        
        // Debug log the response data
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Response data: \(jsonString)")
        }
        
        // If success status code
        if httpResponse.statusCode == 200 {
            // Use a simplified approach for decoding
            do {
                // First try APIResponse wrapper
                let apiResponse = try JSONDecoder().decode(APIResponse<[TaskResponse]>.self, from: data)
                
                // If we have data in the response, use it
                if let eventTasks = apiResponse.data {
                    DispatchQueue.main.async {
                        self.tasks = eventTasks
                    }
                    print("✅ Success! Found \(eventTasks.count) tasks")
                    return
                }
                
                // If data is nil, try direct decoding
                let tasks = try JSONDecoder().decode([TaskResponse].self, from: data)
                DispatchQueue.main.async {
                    self.tasks = tasks
                }
                print("✅ Success! Directly decoded \(tasks.count) tasks")
                
            } catch {
                print("❌ Error decoding response: \(error)")
                throw TaskError.apiError("Ошибка чтения данных задач: \(error.localizedDescription)")
            }
        } else {
            // Error status code
            if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                let errorMsg = errorResponse.error ?? "Ошибка при загрузке задач (код: \(httpResponse.statusCode))"
                print("❌ API error: \(errorMsg)")
                throw TaskError.apiError(errorMsg)
            } else {
                let errorMsg = "Ошибка сервера: HTTP \(httpResponse.statusCode)"
                print("❌ HTTP error: \(errorMsg)")
                throw TaskError.apiError(errorMsg)
            }
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
            
            print("🔍 Event creator check response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Try to decode the response
                do {
                    let eventResponse = try JSONDecoder().decode(APIResponse<EventResponse>.self, from: data)
                    if let event = eventResponse.data {
                        // Check if current user is the event creator and update on main thread
                        let isCreator = event.organizerId == currentUserId
                        DispatchQueue.main.async {
                            self.isEventCreator = isCreator
                        }
                        print("✅ User \(currentUserId ?? 0) is \(isCreator ? "" : "not ")the event creator")
                        return
                    }
                } catch {
                    print("⚠️ Could not determine event creator status: \(error)")
                }
                
                // Default if we couldn't parse
                DispatchQueue.main.async {
                    self.isEventCreator = false
                }
            } else {
                // Non-200 status code
                print("❌ Failed to get event details: HTTP \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.isEventCreator = false
                }
            }
        } catch {
            // Error occurred
            print("❌ Error checking event creator status: \(error)")
            DispatchQueue.main.async {
                self.isEventCreator = false
            }
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
                    do {
                        try await fetchTasks(eventId: task.eventId)
                    } catch {
                        print("Warning: Failed to refresh tasks after update: \(error)")
                        // Continue anyway since we've already updated locally
                    }
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
                    do {
                        try await fetchTasks(eventId: eventId)
                    } catch {
                        print("Warning: Failed to refresh tasks after creating a new task: \(error)")
                        // Continue anyway since we've already added the new task locally
                    }
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
            // Update UI on main thread
            DispatchQueue.main.async {
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = self.tasks[index]
                    let isCurrentUserAlreadyAssigned = task.assignedTo == self.currentUserId
                    
                    // Create a new task with toggled assignedTo
                    let updatedTask = TaskResponse(
                        id: task.id,
                        title: task.title,
                        description: task.description,
                        budget: task.budget,
                        points: task.points,
                        eventId: task.eventId,
                        assignedTo: isCurrentUserAlreadyAssigned ? nil : self.currentUserId,
                        isCompleted: task.isCompleted
                    )
                    self.tasks[index] = updatedTask
                }
            }
            return
        }
        
        // Set loading state
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Reset loading state when done
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
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
                    // Update the task in the tasks array on the main thread
                    DispatchQueue.main.async {
                        if let index = self.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                            self.tasks[index] = updatedTask
                        }
                    }
                    
                    // No need to refresh entire task list - we already updated this task
                    print("✅ Successfully toggled task assignment for task ID: \(taskId)")
                }
            } else {
                // Handle error
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task assignment")
                } else {
                    throw TaskError.apiError("Failed to toggle task assignment: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            // Update error state on main thread
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.showError = true
            }
            print("❌ Error toggling task assignment: \(error.localizedDescription)")
        }
    }
    
    // Toggle task completion status
    func toggleTaskCompletion(taskId: Int) async {
        // In preview mode, update the task directly
        if isPreviewMode {
            // Update UI on main thread
            DispatchQueue.main.async {
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = self.tasks[index]
                    
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
                    self.tasks[index] = updatedTask
                }
            }
            return
        }
        
        // Set loading state
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Reset loading state when done
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
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
                    // Update the task in the tasks array on the main thread
                    DispatchQueue.main.async {
                        if let index = self.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                            self.tasks[index] = updatedTask
                        }
                    }
                    
                    // No need to refresh entire task list - we already updated this task
                    print("✅ Successfully toggled task completion for task ID: \(taskId)")
                }
            } else {
                // Handle error
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task completion")
                } else {
                    throw TaskError.apiError("Failed to toggle task completion: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            // Update error state on main thread
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.showError = true
            }
            print("❌ Error toggling task completion: \(error.localizedDescription)")
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

enum TaskError: Error, CustomStringConvertible {
    case invalidURL
    case invalidResponse
    case unauthorized
    case apiError(String)
    
    var description: String {
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
    
    var message: String {
        return description
    }
} 