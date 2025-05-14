import XCTest
@testable import itsplanned

final class RegisterHandlerTests: XCTestCase {
    let baseURL = "http://localhost:8080"
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRegisterSuccess() async throws {
        let uniqueEmail = "test_\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "Test@123"
        
        let registerRequest = RegisterRequest(email: uniqueEmail, password: password)
        let jsonData = try JSONEncoder().encode(registerRequest)
        
        guard let url = URL(string: "\(baseURL)/register") else {
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
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct RegistrationResponse: Codable {
            let message: String
            let user: UserResponse
        }
        
        do {
            let response = try decoder.decode(RegistrationResponse.self, from: data)
            XCTAssertNotNil(response.user)
            XCTAssertEqual(response.user.email, uniqueEmail)
        } catch {
            if let apiResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                XCTAssertNil(apiResponse.error, "Response should not contain an error")
                XCTAssertNotNil(apiResponse.message, "Response should contain a message")
            } else {
                XCTFail("Failed to decode response: \(error)")
            }
        }
    }
    
    func testRegisterWithExistingEmail() async throws {
        let email = "existing_\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "Test@123"
        
        do {
            let registerRequest = RegisterRequest(email: email, password: password)
            let jsonData = try JSONEncoder().encode(registerRequest)
            
            guard let url = URL(string: "\(baseURL)/register") else {
                XCTFail("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            _ = try await URLSession.shared.data(for: request)
        } catch {
            XCTFail("First registration should succeed: \(error)")
        }
        
        let registerRequest = RegisterRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(registerRequest)
        
        guard let url = URL(string: "\(baseURL)/register") else {
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
        
        XCTAssertNotEqual(httpResponse.statusCode, 200, "Status code should not be 200 for duplicate email")
        
        if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
            XCTAssertNotNil(errorResponse.error, "Response should contain an error message")
        }
    }
    
    func testRegisterWithInvalidEmail() async throws {
        let email = "invalid-email"
        let password = "Test@123"
        
        let registerRequest = RegisterRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(registerRequest)
        
        guard let url = URL(string: "\(baseURL)/register") else {
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
} 
