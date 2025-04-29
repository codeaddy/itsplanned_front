//
//  itsplannedApp.swift
//  itsplanned
//
//  Created by Владислав Сизикин on 15.02.2025.
//

import SwiftUI
import Inject
import OSLog
import UserNotifications
import UIKit

private let logger = Logger(subsystem: "com.itsplanned", category: "App")

@main
struct ItsplannedApp: App {
    @ObserveInjection var inject
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Define the redirect URI for easy reference
    private let googleCallbackURI = "itsplanned://callback/auth"
    
    init() {
        // Configure NotificationManager and request permissions
        configureNotifications()
        
        // Start task status event service if already authenticated
        Task {
            if await KeychainManager.shared.getToken() != nil {
                logger.info("User is already authenticated, starting task status event service")
                TaskStatusEventService.shared.startBackgroundFetching()
            }
        }
        
        // Configure background fetch
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView(authViewModel: authViewModel)
                } else {
                    AuthView(viewModel: authViewModel)
                }
            }
            .animation(.default, value: authViewModel.isAuthenticated)
            .onOpenURL { url in
                // Handle incoming URLs for OAuth callbacks
                logger.info("App received URL: \(url.absoluteString)")
                
                // Check if this is a Google OAuth callback
                if url.absoluteString.starts(with: googleCallbackURI) {
                    logger.info("Processing Google OAuth callback URL")
                    // The UserProfileView will handle this with its own .onOpenURL
                } else {
                    logger.warning("Received unrecognized URL: \(url.absoluteString)")
                }
            }
        }
    }
    
    private func configureNotifications() {
        // Request notification permissions through NotificationManager
        NotificationManager.shared.requestPermissions { granted in
            if granted {
                logger.info("Notification permissions granted via NotificationManager")
            } else {
                logger.warning("Notification permissions denied via NotificationManager")
            }
        }
    }
}

// MARK: - UIApplicationDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.info("Background fetch triggered")
        
        Task {
            do {
                try await TaskStatusEventService.shared.fetchUnreadEvents()
                completionHandler(.newData)
            } catch {
                logger.error("Background fetch failed: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
}
