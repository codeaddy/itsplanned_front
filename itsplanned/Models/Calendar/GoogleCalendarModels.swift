import Foundation

struct GoogleOAuthURLResponse: Codable {
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case url
    }
}

struct GoogleOAuthCallbackResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiry: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiry
    }
}

struct SaveOAuthTokenRequest: Codable {
    let accessToken: String
    let refreshToken: String
    let expiry: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiry
    }
}

struct ImportCalendarEventsResponse: Codable {
    let message: String
    let eventsImported: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case eventsImported = "events_imported"
    }
}

