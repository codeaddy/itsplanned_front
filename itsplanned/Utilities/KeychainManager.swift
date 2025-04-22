import Foundation
import Security

actor KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let tokenKey = "auth_token"
    private let userIdKey = "user_id"
    
    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("Error saving token to Keychain: \(status)")
            return
        }
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            print("Error deleting token from Keychain: \(status)")
            return
        }
    }
    
    func saveUserId(_ userId: Int) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }
    
    func getUserId() -> Int? {
        let userId = UserDefaults.standard.integer(forKey: userIdKey)
        return userId != 0 ? userId : nil
    }
} 