import XCTest
@testable import itsplanned

final class LoginHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLoginSuccess() async throws {
        let email = "test_\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "Test@123"
        
        try await registerUser(email: email, password: password)
        
        let loginRequest = LoginRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
        
        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            XCTAssertFalse(loginResponse.token.isEmpty, "Token should not be empty")
        } catch {
            let apiResponse = try? JSONDecoder().decode(APIResponse<LoginResponse>.self, from: data)
            if let loginData = apiResponse?.data {
                XCTAssertFalse(loginData.token.isEmpty, "Token should not be empty")
            } else {
                XCTFail("Failed to decode response: \(error)")
            }
        }
    }
    
    func testLoginWithInvalidCredentials() async throws {
        let email = "nonexistent_\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "WrongPassword"
        
        let loginRequest = LoginRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertNotEqual(httpResponse.statusCode, 200, "Status code should not be 200 for invalid credentials")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
        }
    }
    
    func testLoginWithInvalidEmail() async throws {
        let email = "invalid-email"
        let password = "Test@123"
        
        let loginRequest = LoginRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertNotEqual(httpResponse.statusCode, 200, "Status code should not be 200 for invalid email")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
        }
    }
    
    func testLoginWithCorrectEmailWrongPassword() async throws {
        let email = "wrong_pass_\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "Test@123"
        let wrongPassword = "WrongPass@123"
        
        try await registerUser(email: email, password: password)
        
        let loginRequest = LoginRequest(email: email, password: wrongPassword)
        let jsonData = try JSONEncoder().encode(loginRequest)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }
        
        XCTAssertNotEqual(httpResponse.statusCode, 200, "Status code should not be 200 for correct email but wrong password")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
        }
    }
    
    private func registerUser(email: String, password: String) async throws {
        let registerRequest = RegisterRequest(email: email, password: password)
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
} 