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
    
    private var currentUserId: Int?
    private var isPreviewMode = false
    
    func setCurrentUserId(_ id: Int) {
        currentUserId = id
    }
    
    func skipAPICallsForPreview() {
        isPreviewMode = true
    }
    
    func setIsEventCreator(_ isCreator: Bool) {
        isEventCreator = isCreator
    }
    
    func fetchTasks(eventId: Int) async throws {
        guard !isPreviewMode else { 
            print("Preview mode: skipping API call")
            return 
        }
        
        print("Fetching tasks for event ID: \(eventId)")
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        await checkIfEventCreator(eventId: eventId)
        
        guard let token = await KeychainManager.shared.getToken() else {
            print("No auth token available")
            throw TaskError.unauthorized
        }
        
        guard var urlComponents = URLComponents(string: "\(APIConfig.baseURL)/tasks") else {
            print("Invalid URL components")
            throw TaskError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "event_id", value: String(eventId))
        ]
        
        guard let url = urlComponents.url else {
            print("Failed to construct URL with query parameters")
            throw TaskError.invalidURL
        }
        
        print("Making request to: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response type")
            throw TaskError.invalidResponse
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response data: \(jsonString)")
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse<[TaskResponse]>.self, from: data)
                
                if let eventTasks = apiResponse.data {
                    DispatchQueue.main.async {
                        self.tasks = eventTasks
                    }
                    print("Success! Found \(eventTasks.count) tasks")
                    return
                } else {
                    DispatchQueue.main.async {
                        self.tasks = []
                    }
                    print("Success! No tasks found for this event")
                    return
                }
                
            } catch {
                print("Error decoding response: \(error)")
                throw TaskError.apiError("Ошибка чтения данных задач: \(error.localizedDescription)")
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                let errorMsg = errorResponse.error ?? "Ошибка при загрузке задач (код: \(httpResponse.statusCode))"
                print("API error: \(errorMsg)")
                throw TaskError.apiError(errorMsg)
            } else {
                let errorMsg = "Ошибка сервера: HTTP \(httpResponse.statusCode)"
                print("HTTP error: \(errorMsg)")
                throw TaskError.apiError(errorMsg)
            }
        }
    }
    
    private func checkIfEventCreator(eventId: Int) async {
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events/\(eventId)") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            print("Event creator check response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    let eventResponse = try JSONDecoder().decode(APIResponse<EventResponse>.self, from: data)
                    if let event = eventResponse.data {
                        let isCreator = event.organizerId == currentUserId
                        DispatchQueue.main.async {
                            self.isEventCreator = isCreator
                        }
                        print("User \(currentUserId ?? 0) is \(isCreator ? "" : "not ")the event creator")
                        return
                    }
                } catch {
                    print("Could not determine event creator status: \(error)")
                }
                
                DispatchQueue.main.async {
                    self.isEventCreator = false
                }
            } else {
                print("Failed to get event details: HTTP \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.isEventCreator = false
                }
            }
        } catch {
            print("Error checking event creator status: \(error)")
            DispatchQueue.main.async {
                self.isEventCreator = false
            }
        }
    }
    
    func updateTask(taskId: Int, title: String, description: String?, budget: Double?, points: Int?) async -> Bool {
        if isPreviewMode {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                let task = tasks[index]
                
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
            
            guard let url = URL(string: "\(APIConfig.baseURL)/tasks/\(taskId)") else {
                throw TaskError.invalidURL
            }
            
            struct UpdateTaskRequest: Codable {
                let title: String
                let description: String?
                let budget: Double?
                let points: Int?
                
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
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let requestData = try? encoder.encode(updateRequest),
               let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("Update task request body: \(requestString)")
                print("Update task request body: \(requestString)")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(updateRequest)
            
            print("Update task URL: \(url)")
            print("Update task method: \(request.httpMethod ?? "unknown")")
            print("Update task headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            logger.debug("Update task response status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Update task response: \(jsonString)")
                print("Update task response: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                if let task = tasks.first(where: { $0.id == taskId }) {
                    if let index = tasks.firstIndex(where: { $0.id == taskId }) {
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
                    
                    do {
                        try await fetchTasks(eventId: task.eventId)
                    } catch {
                        print("Warning: Failed to refresh tasks after update: \(error)")
                    }
                }
                return true
            } else {
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
    
    func createTask(eventId: Int) async -> Bool {
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
            
            guard let url = URL(string: "\(APIConfig.baseURL)/tasks") else {
                throw TaskError.invalidURL
            }
            
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
                    
                    do {
                        try await fetchTasks(eventId: eventId)
                    } catch {
                        print("Warning: Failed to refresh tasks after creating a new task: \(error)")
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
    
    func toggleTaskAssignment(taskId: Int) async {
        if isPreviewMode {
            DispatchQueue.main.async {
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = self.tasks[index]
                    let isCurrentUserAlreadyAssigned = task.assignedTo == self.currentUserId
                    
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
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/tasks/\(taskId)/assign") else {
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
                    DispatchQueue.main.async {
                        if let index = self.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                            self.tasks[index] = updatedTask
                        }
                    }
                    
                    print("Successfully toggled task assignment for task ID: \(taskId)")
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task assignment")
                } else {
                    throw TaskError.apiError("Failed to toggle task assignment: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.showError = true
            }
            print("Error toggling task assignment: \(error.localizedDescription)")
        }
    }
    
    func toggleTaskCompletion(taskId: Int) async {
        if isPreviewMode {
            DispatchQueue.main.async {
                if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = self.tasks[index]
                    
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
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/tasks/\(taskId)/complete") else {
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
                    DispatchQueue.main.async {
                        if let index = self.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
                            self.tasks[index] = updatedTask
                        }
                    }
                    
                    print("Successfully toggled task completion for task ID: \(taskId)")
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to toggle task completion")
                } else {
                    throw TaskError.apiError("Failed to toggle task completion: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.showError = true
            }
            print("Error toggling task completion: \(error.localizedDescription)")
        }
    }
    
    func isCurrentUserAssigned(to task: TaskResponse) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        return task.assignedTo == currentUserId
    }
    
    func startAddingTask() {
        isAddingTask = true
        newTaskTitle = ""
    }
    
    func cancelAddingTask() {
        isAddingTask = false
        newTaskTitle = ""
    }
    
    func deleteTask(taskId: Int) async -> Bool {
        if isPreviewMode {
            tasks.removeAll { $0.id == taskId }
            return true
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                throw TaskError.unauthorized
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/tasks/\(taskId)") else {
                throw TaskError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TaskError.invalidResponse
            }
            
            print("Delete task response status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Delete task response: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                    tasks.remove(at: index)
                }
                return true
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw TaskError.apiError(errorResponse.error ?? "Failed to delete task")
                } else {
                    throw TaskError.apiError("Failed to delete task: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            logger.error("Error deleting task: \(error.localizedDescription)")
        }
        
        return false
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
