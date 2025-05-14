import XCTest
@testable import itsplanned

final class AIMessageHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    var token: String?
    let testEmail = "ai_test_\(Int(Date().timeIntervalSince1970))@example.com"
    let testPassword = "Test@123"
    
    override func setUp() async throws {
        try await super.setUp()
        try await registerAndLogin()
    }
    
    override func tearDown() async throws {
        await KeychainManager.shared.deleteToken()
        try await super.tearDown()
    }
    
    func testSendAIMessage() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let messages = [
            YandexGPTMessage(role: "user", text: "Hello, can you help me plan a birthday party?")
        ]
        
        let aiRequest = YandexGPTRequest(messages: messages)
        
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        let aiResponse = try JSONDecoder().decode(YandexGPTResponse.self, from: data)
        XCTAssertFalse(aiResponse.message.isEmpty, "AI response should not be empty")
    }
    
    func testSendAIMessageWithMultipleMessages() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let messages = [
            YandexGPTMessage(role: "user", text: "Hello, can you help me plan a birthday party?"),
            YandexGPTMessage(role: "assistant", text: "Of course! I'd be happy to help you plan a birthday party! 🎉 Could you tell me a bit more about what you're looking for? For example: Who is the birthday for? What's their age? And what kind of party theme or activities are you considering?"),
            YandexGPTMessage(role: "user", text: "It's for my friend's 30th birthday. Something with food and games.")
        ]
        
        let aiRequest = YandexGPTRequest(messages: messages)
        
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        let aiResponse = try JSONDecoder().decode(YandexGPTResponse.self, from: data)
        XCTAssertFalse(aiResponse.message.isEmpty, "AI response should not be empty")
    }
    
    func testSendAIMessageWithoutToken() async throws {
        let messages = [
            YandexGPTMessage(role: "user", text: "Hello, can you help me plan a birthday party?")
        ]
        
        let aiRequest = YandexGPTRequest(messages: messages)
        
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
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
    
    func testSendAIMessageWithInvalidToken() async throws {
        let invalidToken = "invalid_token_123456"
        
        let messages = [
            YandexGPTMessage(role: "user", text: "Hello, can you help me plan a birthday party?")
        ]
        
        let aiRequest = YandexGPTRequest(messages: messages)
        
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(invalidToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
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
    
    func testSendAIMessageWithEmptyMessages() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        let messages: [YandexGPTMessage] = []
        
        let aiRequest = YandexGPTRequest(messages: messages)
        
        guard let url = URL(string: "\(baseURL)/ai/message") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(aiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertNotEqual(httpResponse.statusCode, 200, "Status code should not be 200 for empty messages")
        
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
} 