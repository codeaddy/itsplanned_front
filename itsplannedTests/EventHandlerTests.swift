import XCTest
@testable import itsplanned

final class EventHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    var token: String?
    let testEmail = "event_test_\(Int(Date().timeIntervalSince1970))@example.com"
    let testPassword = "Test@123"
    var createdEventId: Int?
    
    override func setUp() async throws {
        try await super.setUp()
        try await registerAndLogin()
    }
    
    override func tearDown() async throws {
        if let eventId = createdEventId {
            try await deleteEvent(id: eventId)
        }
        await KeychainManager.shared.deleteToken()
        try await super.tearDown()
    }
    
    func testCreateEvent() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let eventName = "Test Event \(Int(Date().timeIntervalSince1970))"
        let eventDescription = "This is a test event created by automated tests"
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
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(eventRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
              let eventData = apiResponse.data else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertEqual(eventData.name, eventName)
        XCTAssertEqual(eventData.description, eventDescription)
        XCTAssertEqual(eventData.place, place)
        XCTAssertEqual(eventData.initialBudget, initialBudget)
        
        self.createdEventId = eventData.id
    }
    
    func testGetEventsList() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        try await createTestEvent()
        
        guard let url = URL(string: "\(baseURL)/events") else {
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
        
        struct EventsResponse: Codable {
            let data: [EventResponse]
        }
        
        guard let eventsResponse = try? JSONDecoder().decode(EventsResponse.self, from: data) else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertGreaterThanOrEqual(eventsResponse.data.count, 1, "There should be at least one event")
    }
    
    func testGetEventDetails() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let eventId = try await createTestEvent()
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
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
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
              let eventData = apiResponse.data else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertEqual(eventData.id, eventId)
    }
    
    func testUpdateEvent() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let eventId = try await createTestEvent()
        
        let updatedName = "Updated Test Event \(Int(Date().timeIntervalSince1970))"
        let updatedDescription = "This is an updated test event"
        
        let updateRequest = UpdateEventRequest(
            name: updatedName,
            description: updatedDescription,
            eventDateTime: nil,
            place: nil,
            budget: nil
        )
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
              let eventData = apiResponse.data else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertEqual(eventData.name, updatedName)
        XCTAssertEqual(eventData.description, updatedDescription)
    }
    
    func testDeleteEvent() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let eventId = try await createTestEvent()
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        guard let apiResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertNil(apiResponse.error)
        XCTAssertNotNil(apiResponse.message)
        
        self.createdEventId = nil
    }
    
    func testGetEventBudget() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let eventId = try await createTestEvent()
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)/budget") else {
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
        
        guard let budgetResponse = try? JSONDecoder().decode(EventBudgetResponse.self, from: data) else {
            XCTFail("Failed to decode response")
            return
        }
        
        XCTAssertEqual(budgetResponse.initialBudget, 1000.0)
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
        
        let eventName = "Test Event \(Int(Date().timeIntervalSince1970))"
        let eventDescription = "This is a test event created by automated tests"
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
        
        self.createdEventId = eventData.id
        return eventData.id
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
