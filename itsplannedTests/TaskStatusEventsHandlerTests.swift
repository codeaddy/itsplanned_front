import XCTest
@testable import itsplanned

final class TaskStatusEventsHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    var token: String?
    let testEmail = "task_events_test_\(Int(Date().timeIntervalSince1970))@example.com"
    let testPassword = "Test@123"
    var createdEventId: Int?
    var createdTaskId: Int?
    
    override func setUp() async throws {
        try await super.setUp()
        try await registerAndLogin()
        createdEventId = try await createTestEvent()
        createdTaskId = try await createTestTask(eventId: createdEventId!)
    }
    
    override func tearDown() async throws {
        if let taskId = createdTaskId {
            try await deleteTask(id: taskId)
        }
        
        if let eventId = createdEventId {
            try await deleteEvent(id: eventId)
        }
        
        await KeychainManager.shared.deleteToken()
        try await super.tearDown()
    }
    
    func testGetUnreadTaskStatusEvents() async throws {
        guard let token = self.token, let taskId = self.createdTaskId else {
            XCTFail("No authentication token or task ID")
            return
        }
        
        try await assignTask(taskId: taskId)
        try await completeTask(taskId: taskId)
        
        guard let url = URL(string: "\(baseURL)/task-status-events/unread") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        let decoder = JSONDecoder()
        let eventsResponse = try decoder.decode(TaskStatusEventsResponse.self, from: data)
        
        XCTAssertFalse(eventsResponse.events.isEmpty, "There should be task status events")
        
        let taskEvents = eventsResponse.events.filter { $0.taskId == taskId }
        XCTAssertFalse(taskEvents.isEmpty, "There should be events for our test task")
    }
    
    func testGetUnreadTaskStatusEventsWithoutToken() async throws {
        guard let url = URL(string: "\(baseURL)/task-status-events/unread") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 401, "Status code should be 401 Unauthorized")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error)
        }
    }
    
    func testGetUnreadTaskStatusEventsWithInvalidToken() async throws {
        let invalidToken = "invalid_token_123456"
        
        guard let url = URL(string: "\(baseURL)/task-status-events/unread") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(invalidToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 401, "Status code should be 401 Unauthorized")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error)
        }
    }
    
    private func registerAndLogin() async throws {
        try await registerUser()
        try await loginUser()
    }
    
    private func registerUser() async throws {
        let registerRequest = RegisterRequest(email: testEmail, password: testPassword)
        let jsonData = try JSONEncoder().encode(registerRequest)
        
        guard let url = URL(string: "\(baseURL)/register") else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Registration failed with status code: \(httpResponse.statusCode)"])
        }
    }
    
    private func loginUser() async throws {
        let loginRequest = LoginRequest(email: testEmail, password: testPassword)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Login failed with status code: \(httpResponse.statusCode)"])
        }
        
        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            self.token = loginResponse.token
        } catch {
            let apiResponse = try? JSONDecoder().decode(APIResponse<LoginResponse>.self, from: data)
            if let loginData = apiResponse?.data {
                self.token = loginData.token
            } else {
                throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode login response"])
            }
        }
    }
    
    private func createTestEvent() async throws -> Int {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        let eventName = "Test Event for Task Events \(Int(Date().timeIntervalSince1970))"
        let eventDescription = "This is a test event for task status events tests"
        let dateFormatter = ISO8601DateFormatter()
        let eventDateTime = dateFormatter.string(from: Date().addingTimeInterval(86400)) // Tomorrow
        let place = "Test Location"
        let initialBudget = 1000.0
        
        let eventRequest = CreateEventRequest(
            name: eventName,
            description: eventDescription,
            eventDateTime: eventDateTime,
            place: place,
            initialBudget: initialBudget
        )
        
        guard let url = URL(string: "\(baseURL)/events") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(eventRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Event creation failed with status code: \(httpResponse.statusCode)"])
        }
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
              let eventData = apiResponse.data else {
            throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"])
        }
        
        return eventData.id
    }
    
    private func createTestTask(eventId: Int) async throws -> Int {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        let taskTitle = "Test Task for Status Events \(Int(Date().timeIntervalSince1970))"
        let taskDescription = "This is a test task for status events tests"
        let budget = 100.0
        let points = 5
        
        let taskRequest = CreateTaskRequest(
            title: taskTitle,
            description: taskDescription,
            budget: budget,
            points: points,
            eventId: eventId,
            assignedTo: nil
        )
        
        guard let url = URL(string: "\(baseURL)/tasks") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(taskRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task creation failed with status code: \(httpResponse.statusCode)"])
        }
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<TaskResponse>.self, from: data),
              let taskData = apiResponse.data else {
            throw NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"])
        }
        
        return taskData.id
    }
    
    private func assignTask(taskId: Int) async throws {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        guard let url = URL(string: "\(baseURL)/tasks/\(taskId)/assign") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task assignment failed with status code: \(httpResponse.statusCode)"])
        }
    }
    
    private func completeTask(taskId: Int) async throws {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        guard let url = URL(string: "\(baseURL)/tasks/\(taskId)/complete") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task completion failed with status code: \(httpResponse.statusCode)"])
        }
    }
    
    private func deleteTask(id: Int) async throws {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        guard let url = URL(string: "\(baseURL)/tasks/\(id)") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 404 {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Task deletion failed with status code: \(httpResponse.statusCode)"])
        }
    }
    
    private func deleteEvent(id: Int) async throws {
        guard let token = self.token else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authentication token"])
        }
        
        guard let url = URL(string: "\(baseURL)/events/\(id)") else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 404 {
            throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Event deletion failed with status code: \(httpResponse.statusCode)"])
        }
    }
} 