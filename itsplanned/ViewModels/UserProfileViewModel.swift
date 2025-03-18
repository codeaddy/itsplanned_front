import Foundation
import UIKit

class UserProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var isImageLoading = false
    
    let baseURL = "http://localhost:8080"
    
    // Function to update user display name
    func updateDisplayName(userId: Int, newName: String) async -> Bool {
        // Set loading state on main thread
        await MainActor.run {
            isLoading = true
        }
        
        // Ensure we reset the loading state when we exit the function
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            guard let token = await KeychainManager.shared.getToken() else {
                await setError("Авторизация не действительна")
                return false
            }
            
            guard let url = URL(string: "\(baseURL)/profile") else {
                await setError("Некорректный URL")
                return false
            }
            
            // Create request body with the updated display name
            let requestBody: [String: Any] = ["display_name": newName]
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await setError("Некорректный ответ от сервера")
                return false
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    await setError(errorResponse.error ?? "Не удалось обновить профиль")
                } else {
                    await setError("Не удалось обновить профиль. Код ошибки: \(httpResponse.statusCode)")
                }
                return false
            }
        } catch {
            await setError("Ошибка сети: \(error.localizedDescription)")
            return false
        }
    }
    
    // This is a placeholder for future implementation
    func updateProfilePicture(userId: Int, image: UIImage) async -> Bool {
        // This functionality will be implemented in the future
        await MainActor.run {
            isImageLoading = true
        }
        
        // Ensure we reset the loading state when we exit the function
        defer {
            Task { @MainActor in
                isImageLoading = false
            }
        }
        
        // Simulate delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return success for now since this is a stub
        return true
    }
    
    private func setError(_ message: String) async {
        await MainActor.run {
            self.error = message
            self.showError = true
        }
    }
} 