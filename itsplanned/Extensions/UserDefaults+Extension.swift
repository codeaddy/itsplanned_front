import Foundation

extension UserDefaults {
    static let userEmailKey = "user_email"
    
    var email: String? {
        get {
            string(forKey: UserDefaults.userEmailKey)
        }
        set {
            set(newValue, forKey: UserDefaults.userEmailKey)
        }
    }
} 
