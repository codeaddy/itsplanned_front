import XCTest
@testable import itsplanned

final class ProfileHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    var token: String?
    var userId: Int?
    let testEmail = "profile_test_\(Int(Date().timeIntervalSince1970))@example.com"
    let testPassword = "Test@123"
    
    override func setUp() async throws {
        try await super.setUp()
        try await registerAndLogin()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        await KeychainManager.shared.deleteToken()
    }
    
    func testGetProfile() async throws {
        guard let token = self.token else {
            XCTFail("No authentication token")
            return
        }
        
        guard let url = URL(string: "\(baseURL)/profile") else {
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
        
        let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        XCTAssertEqual(profileResponse.user.email, testEmail)
        XCTAssertEqual(profileResponse.user.id, userId)
    }
    
    func testGetProfileWithoutToken() async throws {
        guard let url = URL(string: "\(baseURL)/profile") else {
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
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
        }
    }
    
    func testGetProfileWithInvalidToken() async throws {
        let invalidToken = "invalid_token_123456"
        
        guard let url = URL(string: "\(baseURL)/profile") else {
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
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
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
            try await fetchUserIdFromProfile(token: loginResponse.token)
        } catch {
            let apiResponse = try? JSONDecoder().decode(APIResponse<LoginResponse>.self, from: data)
            if let loginData = apiResponse?.data {
                self.token = loginData.token
                try await fetchUserIdFromProfile(token: loginData.token)
            } else {
                throw NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to decode login response"])
            }
        }
    }
    
    private func fetchUserIdFromProfile(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/profile") else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Response is not HTTPURLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Profile fetch failed with status code: \(httpResponse.statusCode)"])
        }
        
        let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        self.userId = profileResponse.user.id
    }
} 
