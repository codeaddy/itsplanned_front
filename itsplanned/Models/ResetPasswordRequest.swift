import Foundation

struct SubmitNewPasswordRequest: Codable {
    let token: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token = "token"
        case newPassword = "new_password"
    }
} 