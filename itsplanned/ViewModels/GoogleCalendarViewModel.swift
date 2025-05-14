import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.itsplanned", category: "GoogleCalendar")

@MainActor
final class GoogleCalendarViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?
    @Published var showError = false
    
    let redirectURI = "itsplanned://callback/auth"
    
    func getGoogleAuthURL() async -> URL? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                setError("Авторизация не действительна")
                return nil
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/auth/google") else {
                setError("Некорректный URL")
                return nil
            }
            
            logger.debug("Requesting Google auth URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                setError("Некорректный ответ от сервера")
                return nil
            }
            
            logger.debug("Auth URL response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Auth URL response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let authResponse = try JSONDecoder().decode(GoogleOAuthURLResponse.self, from: data)
                    logger.info("Successfully obtained auth URL: \(authResponse.url)")
                    return URL(string: authResponse.url)
                } catch {
                    logger.error("Failed to decode auth URL response: \(error.localizedDescription)")
                    do {
                        let apiResponse = try JSONDecoder().decode(APIResponse<GoogleOAuthURLResponse>.self, from: data)
                        if let responseData = apiResponse.data {
                            logger.info("Successfully obtained auth URL (from wrapper): \(responseData.url)")
                            return URL(string: responseData.url)
                        } else {
                            setError("Ответ сервера не содержит URL")
                            return nil
                        }
                    } catch {
                        logger.error("Failed to decode API response: \(error.localizedDescription)")
                        setError("Ошибка декодирования ответа: \(error.localizedDescription)")
                        return nil
                    }
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    setError(errorResponse.error ?? "Не удалось получить ссылку авторизации")
                } else {
                    setError("Не удалось получить ссылку авторизации. Код ошибки: \(httpResponse.statusCode)")
                }
                return nil
            }
        } catch {
            logger.error("Network error getting auth URL: \(error.localizedDescription)")
            setError("Ошибка сети: \(error.localizedDescription)")
            return nil
        }
    }
    
    func handleCallback(code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard var urlComponents = URLComponents(string: "\(APIConfig.baseURL)/auth/google/callback") else {
                setError("Некорректный URL для callback")
                return false
            }
            
            urlComponents.queryItems = [
                URLQueryItem(name: "code", value: code)
            ]
            
            guard let url = urlComponents.url else {
                setError("Некорректный URL с параметрами для callback")
                return false
            }
            
            logger.debug("Requesting token exchange: \(url.absoluteString)")
            
            guard let token = await KeychainManager.shared.getToken() else {
                setError("Авторизация не действительна")
                return false
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                setError("Некорректный ответ от сервера")
                return false
            }
            
            logger.debug("Token exchange response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Token exchange response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let tokenResponse = try JSONDecoder().decode(GoogleOAuthCallbackResponse.self, from: data)
                    logger.info("Successfully received tokens")
                    return await saveTokens(tokenResponse: tokenResponse)
                } catch {
                    logger.error("Failed to decode token response: \(error.localizedDescription)")
                    setError("Ошибка декодирования ответа: \(error.localizedDescription)")
                    return false
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    setError(errorResponse.error ?? "Не удалось получить токены авторизации")
                } else {
                    setError("Не удалось получить токены авторизации. Код ошибки: \(httpResponse.statusCode)")
                }
                return false
            }
        } catch {
            logger.error("Network error in token exchange: \(error.localizedDescription)")
            setError("Ошибка обработки callback: \(error.localizedDescription)")
            return false
        }
    }
    
    private func saveTokens(tokenResponse: GoogleOAuthCallbackResponse) async -> Bool {
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                setError("Авторизация не действительна")
                return false
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/auth/oauth/save") else {
                setError("Некорректный URL для сохранения токенов")
                return false
            }
            
            let saveRequest = SaveOAuthTokenRequest(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiry: tokenResponse.expiry
            )
            
            let jsonData = try JSONEncoder().encode(saveRequest)
            
            logger.debug("Saving tokens to server")
            
            if let requestString = String(data: jsonData, encoding: .utf8) {
                logger.debug("Save tokens request body: \(requestString)")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                setError("Некорректный ответ от сервера")
                return false
            }
            
            logger.debug("Save tokens response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Save tokens response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                logger.info("Successfully saved tokens")
                isConnected = true
                return true
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    setError(errorResponse.error ?? "Не удалось сохранить токены авторизации")
                } else {
                    setError("Не удалось сохранить токены авторизации. Код ошибки: \(httpResponse.statusCode)")
                }
                return false
            }
        } catch {
            logger.error("Error saving tokens: \(error.localizedDescription)")
            setError("Ошибка сохранения токенов: \(error.localizedDescription)")
            return false
        }
    }
    
    func importCalendarEvents() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                setError("Авторизация не действительна")
                return false
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)/calendar/import") else {
                setError("Некорректный URL для импорта событий")
                return false
            }
            
            logger.debug("Importing calendar events")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                setError("Некорректный ответ от сервера")
                return false
            }
            
            logger.debug("Import events response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Import events response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let importResponse = try JSONDecoder().decode(ImportCalendarEventsResponse.self, from: data)
                    logger.info("Imported \(importResponse.eventsImported) events: \(importResponse.message)")
                    return true
                } catch {
                    logger.error("Failed to decode import response: \(error.localizedDescription)")
                    do {
                        let apiResponse = try JSONDecoder().decode(APIResponse<ImportCalendarEventsResponse>.self, from: data)
                        if let responseData = apiResponse.data {
                            logger.info("Imported \(responseData.eventsImported) events (from wrapper): \(responseData.message)")
                            return true
                        } else {
                            setError("Ответ сервера не содержит данные об импорте")
                            return false
                        }
                    } catch {
                        logger.error("Failed to decode API response: \(error.localizedDescription)")
                        setError("Ошибка декодирования ответа: \(error.localizedDescription)")
                        return false
                    }
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    setError(errorResponse.error ?? "Не удалось импортировать события")
                } else {
                    setError("Не удалось импортировать события. Код ошибки: \(httpResponse.statusCode)")
                }
                return false
            }
        } catch {
            logger.error("Network error importing events: \(error.localizedDescription)")
            setError("Ошибка импорта событий: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkCalendarConnection() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                isConnected = false
                return
            }
            
            guard var urlComponents = URLComponents(string: "\(APIConfig.baseURL)/calendar/import") else {
                isConnected = false
                return
            }
            
            guard let url = urlComponents.url else {
                isConnected = false
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                isConnected = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                isConnected = true
            } else if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
                isConnected = false
            } else {
                isConnected = false
                
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Failed to check calendar connection: \(responseString)")
                }
            }
        } catch {
            logger.error("Error checking calendar connection: \(error.localizedDescription)")
            isConnected = false
        }
    }
    
    private func setError(_ message: String) {
        self.error = message
        self.showError = true
        logger.error("\(message)")
    }
} 
