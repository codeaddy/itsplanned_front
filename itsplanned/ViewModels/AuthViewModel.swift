import Foundation
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "Auth")

enum AuthError: Error {
    case invalidEmail
    case invalidPassword
    case passwordMismatch
    case networkError(String)
    case unknown
    case invalidData
    
    var message: String {
        switch self {
        case .invalidEmail:
            return "Пожалуйста, введите корректный email"
        case .invalidPassword:
            return "Пароль должен содержать минимум 8 символов"
        case .passwordMismatch:
            return "Пароли не совпадают"
        case .networkError(let message):
            return message
        case .invalidData:
            return "Получены некорректные данные от сервера"
        case .unknown:
            return "Произошла неизвестная ошибка"
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isPasswordResetSuccessful = false
    @Published var error: AuthError?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var currentUser: UserResponse?
    
    private(set) var email: String = ""
    private(set) var password: String = ""
    private let baseURL = "http://localhost:8080"
    
    init() {
        Task {
            if await KeychainManager.shared.getToken() != nil {
                await setAuthenticationState(true)
                await fetchUserProfile()
            }
        }
    }
    
    private func setAuthenticationState(_ authenticated: Bool) async {
        isAuthenticated = authenticated
        if authenticated {
            // Start the background task when authenticated
            TaskStatusEventService.shared.startBackgroundFetching()
        } else {
            // Stop the background task when logged out
            TaskStatusEventService.shared.stopBackgroundFetching()
            currentUser = nil
            email = ""
            password = ""
            await KeychainManager.shared.deleteToken()
            UserDefaults.standard.email = nil
        }
    }
    
    private func logResponse(_ data: Data, for endpoint: String) {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            logger.debug("Response from \(endpoint):\n\(prettyString)")
        }
    }
    
    private func fetchUserProfile() async {
        guard let token = await KeychainManager.shared.getToken() else {
            await setAuthenticationState(false)
            return
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/profile") else {
                throw AuthError.unknown
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(data, for: "/profile")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
                self.currentUser = profileResponse.user
                
                await KeychainManager.shared.saveUserId(profileResponse.user.id)
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw AuthError.networkError(errorResponse.error ?? "Failed to fetch user profile")
            }
        } catch {
            await setAuthenticationState(false)
            if let authError = error as? AuthError {
                self.error = authError
            } else {
                self.error = .networkError(error.localizedDescription)
            }
        }
    }

    func register(email: String, password: String, confirmPassword: String) async {
        guard isValidEmail(email) else {
            error = .invalidEmail
            return
        }
        
        guard isValidPassword(password) else {
            error = .invalidPassword
            return
        }
        
        guard password == confirmPassword else {
            error = .passwordMismatch
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let registerRequest = RegisterRequest(email: email, password: password)
            let jsonData = try JSONEncoder().encode(registerRequest)
            
            guard let url = URL(string: "\(baseURL)/register") else {
                throw AuthError.unknown
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(data, for: "/register")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            try await handleRegistrationResponse(httpResponse: httpResponse, data: data, email: email)
            
        } catch {
            if let authError = error as? AuthError {
                self.error = authError
            } else {
                self.error = .networkError(error.localizedDescription)
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loginRequest = LoginRequest(email: email, password: password)
            let jsonData = try JSONEncoder().encode(loginRequest)
            
            guard let url = URL(string: "\(baseURL)/login") else {
                throw AuthError.unknown
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(data, for: "/login")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            try await handleLoginResponse(httpResponse: httpResponse, data: data, email: email)
            
        } catch {
            if let authError = error as? AuthError {
                self.error = authError
            } else {
                self.error = .networkError(error.localizedDescription)
            }
        }
    }
    
    func resetPassword(email: String) async {
        guard isValidEmail(email) else {
            error = .invalidEmail
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let resetRequest = ResetPasswordRequest(email: email)
            let jsonData = try JSONEncoder().encode(resetRequest)
            
            guard let url = URL(string: "\(baseURL)/password/reset-request") else {
                throw AuthError.unknown
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(data, for: "/password/reset-request")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                isPasswordResetSuccessful = true
            } else {
                let errorResponse = try JSONDecoder().decode(APIResponse<String>.self, from: data)
                throw AuthError.networkError(errorResponse.error ?? "Failed to reset password")
            }
        } catch {
            if let authError = error as? AuthError {
                self.error = authError
            } else {
                self.error = .networkError(error.localizedDescription)
            }
        }
    }

    func logout() {
        Task {
            await setAuthenticationState(false)
        }
    }

    private func handleRegistrationResponse(httpResponse: HTTPURLResponse, data: Data, email: String) async throws {
        if httpResponse.statusCode == 200 {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            await KeychainManager.shared.saveToken(loginResponse.token)
            
            UserDefaults.standard.email = email
            self.email = email
            await setAuthenticationState(true)
            
            await fetchUserProfile()
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                throw AuthError.networkError(errorResponse.error ?? "Registration failed")
            } else {
                throw AuthError.networkError("Registration failed")
            }
        }
    }

    private func handleLoginResponse(httpResponse: HTTPURLResponse, data: Data, email: String) async throws {
        if httpResponse.statusCode == 200 {
            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

                await KeychainManager.shared.saveToken(loginResponse.token)
                
                UserDefaults.standard.email = email
                self.email = email
                await setAuthenticationState(true)
                
                await fetchUserProfile()
            } catch {
                let loginResponse = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: data)
                if let loginData = loginResponse.data {
                    await KeychainManager.shared.saveToken(loginData.token)
                    
                    UserDefaults.standard.email = email
                    self.email = email
                    await setAuthenticationState(true)
                    
                    await fetchUserProfile()
                } else {
                    throw AuthError.networkError("Login response data is missing")
                }
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                throw AuthError.networkError(errorResponse.error ?? "Login failed")
            } else {
                throw AuthError.networkError("Login failed")
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
    }

    // Public method to refresh user profile data
    func refreshUserProfile() async {
        await fetchUserProfile()
    }
    
    // Method to set current user for previews
    #if DEBUG
    func setCurrentUserForPreview(_ user: UserResponse) {
        self.currentUser = user
    }
    #endif
} 
