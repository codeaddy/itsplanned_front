import Foundation
import Combine
import OSLog
import UIKit

class TaskStatusEventService {
    static let shared = TaskStatusEventService()
    private let logger = Logger(subsystem: "com.itsplanned", category: "TaskStatusEventService")
    
    private var backgroundTask: Task<Void, Never>?
    private var lastEventId: Int = 0
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background, starting background task")
        startBackgroundTask()
    }
    
    @objc private func appWillEnterForeground() {
        logger.info("App will enter foreground, stopping background task")
        stopBackgroundTask()
    }
    
    private func startBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopBackgroundTask()
        }
        
        startBackgroundFetching()
    }
    
    private func stopBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        stopBackgroundFetching()
    }
    
    func startBackgroundFetching() {
        logger.info("Starting background task for fetching unread task status events")
        
        stopBackgroundFetching()
        
        backgroundTask = Task {
            while !Task.isCancelled {
                do {
                    try await fetchUnreadEvents()
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
                } catch {
                    logger.error("Error fetching task status events: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                }
            }
        }
    }
    
    func stopBackgroundFetching() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }
    
    func fetchUnreadEvents() async throws {
        guard let token = await KeychainManager.shared.getToken() else {
            logger.warning("Cannot fetch task status events: No auth token available")
            throw NSError(domain: "com.itsplanned", code: 401, userInfo: [NSLocalizedDescriptionKey: "No auth token available"])
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)/task-status-events/unread") else {
            logger.error("Invalid URL for fetching task status events")
            throw NSError(domain: "com.itsplanned", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "com.itsplanned", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("HTTP error \(httpResponse.statusCode)")
            throw NSError(domain: "com.itsplanned", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(TaskStatusEventsResponse.self, from: data)
        
        for event in apiResponse.events {
            if event.id > lastEventId {
                lastEventId = event.id
                
                sendNotificationForEvent(event)
            }
        }
    }
    
    private func sendNotificationForEvent(_ event: TaskStatusEvent) {
        logger.info("Sending notification for task status event: \(event.id)")
        
        NotificationManager.shared.sendTaskStatusNotification(
            title: event.notificationTitle,
            body: event.notificationBody,
            taskId: event.taskId
        )
    }
} 
