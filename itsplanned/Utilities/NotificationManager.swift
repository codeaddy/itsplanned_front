import Foundation
import UserNotifications
import SwiftUI
import OSLog
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let logger = Logger(subsystem: "com.itsplanned", category: "NotificationManager")
    
    private override init() {
        super.init()
        // Set this class as the notification delegate
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                self.logger.info("Notification permission granted")
                
                // Register for remote notifications on the main thread
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                self.logger.warning("Notification permission denied")
            }
            
            // Return result on the main thread
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func sendNotification(title: String, body: String, delay: TimeInterval = 3, identifier: String? = nil) {
        self.logger.info("Preparing to send notification: \(title) - \(body)")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        // Create a unique identifier for this notification or use the provided one
        let requestIdentifier = identifier ?? UUID().uuidString
        
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                self.logger.info("Notification scheduled successfully with ID: \(requestIdentifier)")
                
                // For debugging in simulator, print pending notifications
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    self.logger.info("Current pending notifications: \(requests.count)")
                    for request in requests {
                        self.logger.info("Pending notification: \(request.identifier)")
                    }
                }
            }
        }
    }
    
    func sendTaskStatusNotification(title: String, body: String, taskId: Int) {
        let userInfo = ["taskId": taskId]
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let requestIdentifier = "task-status-\(taskId)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule task notification: \(error.localizedDescription)")
            } else {
                self.logger.info("Task notification scheduled successfully with ID: \(requestIdentifier)")
            }
        }
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification response when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Check if this is a task status notification and extract the task ID
        if let taskId = userInfo["taskId"] as? Int {
            logger.info("User tapped on task status notification for task ID: \(taskId)")
            // For now, we'll just log it
        }
        
        completionHandler()
    }
    
    // Check notification authorization status
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
} 
