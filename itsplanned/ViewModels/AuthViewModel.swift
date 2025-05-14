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
    @Published var registrationCompleted = false
    @Published var successMessage: String? = nil
    
    private(set) var email: String = ""
    private(set) var password: String = ""
    
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
            TaskStatusEventService.shared.startBackgroundFetching()
        } else {
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
            guard let url = URL(string: "\(APIConfig.baseURL)/profile") else {
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
        
        registrationCompleted = false
        isLoading = true
        defer { isLoading = false }
        
        do {
            let registerRequest = RegisterRequest(email: email, password: password)
            let jsonData = try JSONEncoder().encode(registerRequest)
            
            guard let url = URL(string: "\(APIConfig.baseURL)/register") else {
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
        successMessage = nil
        defer { isLoading = false }
        
        do {
            let loginRequest = LoginRequest(email: email, password: password)
            let jsonData = try JSONEncoder().encode(loginRequest)
            
            guard let url = URL(string: "\(APIConfig.baseURL)/login") else {
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
            
            guard let url = URL(string: "\(APIConfig.baseURL)/password/reset-request") else {
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
        Task { @MainActor in
            await setAuthenticationState(false)
        }
    }

    private func handleRegistrationResponse(httpResponse: HTTPURLResponse, data: Data, email: String) async throws {
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            struct RegistrationResponse: Codable {
                let message: String
                let user: UserResponse
            }
            
            do {
                let response = try decoder.decode(RegistrationResponse.self, from: data)
                
                UserDefaults.standard.email = email
                self.email = email
                self.error = nil
                
                isAuthenticated = false
                registrationCompleted = true
                successMessage = "Регистрация выполнена успешно. Теперь вы можете войти."
            } catch {
                if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                    throw AuthError.networkError(errorResponse.error ?? "Registration failed")
                } else {
                    throw AuthError.networkError("Registration data could not be decoded: \(error.localizedDescription)")
                }
            }
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

    func submitNewPassword(token: String, password: String) async {
        guard isValidPassword(password) else {
            error = .invalidPassword
            return
        }
        
        isLoading = true
        
        do {
            let resetRequest = SubmitNewPasswordRequest(token: token, newPassword: password)
            let jsonData = try JSONEncoder().encode(resetRequest)
            
            guard let url = URL(string: "\(APIConfig.baseURL)/password/reset") else {
                throw AuthError.unknown
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(data, for: "/password/reset")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            if httpResponse.statusCode == 200 {
                isPasswordResetSuccessful = true
                
                if let savedEmail = UserDefaults.standard.email {
                    logger.info("Attempting auto-login after password reset with email: \(savedEmail)")
                    await login(email: savedEmail, password: password)
                }
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
        
        isLoading = false
    }

    func refreshUserProfile() async {
        await fetchUserProfile()
    }
    
    #if DEBUG
    func setCurrentUserForPreview(_ user: UserResponse) {
        self.currentUser = user
    }
    #endif
} 
