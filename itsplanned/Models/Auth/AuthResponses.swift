import Foundation

struct LoginResponse: Codable {
    let token: String
}

struct UserResponse: Codable {
    let id: Int
    let email: String
    let displayName: String
    let bio: String?
    let avatar: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case bio
        case avatar
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserProfileResponse: Codable {
    let user: UserResponse
}

struct APIResponse<T: Codable>: Codable {
    let error: String?
    let message: String?
    let data: T?
} 