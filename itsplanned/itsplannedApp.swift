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
    @StateObject private var eventViewModel = EventViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let googleCallbackURI = "itsplanned://callback/auth"
    @State private var resetPasswordToken: String? = nil
    @State private var showResetPasswordView = false
    @State private var showJoinEventAlert = false
    @State private var joinEventMessage: String? = nil
    @State private var isJoiningEvent = false
    
    init() {
        configureNotifications()
        
        Task {
            if await KeychainManager.shared.getToken() != nil {
                logger.info("User is already authenticated, starting task status event service")
                TaskStatusEventService.shared.startBackgroundFetching()
            }
        }
        
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showResetPasswordView, let token = resetPasswordToken {
                    ResetPasswordView(token: token, onDismiss: {
                        showResetPasswordView = false
                        resetPasswordToken = nil
                    })
                    .environmentObject(authViewModel)
                } else if authViewModel.isAuthenticated {
                    MainTabView(authViewModel: authViewModel)
                        .environmentObject(eventViewModel)
                } else {
                    AuthView(viewModel: authViewModel)
                }
            }
            .animation(.default, value: authViewModel.isAuthenticated)
            .animation(.default, value: showResetPasswordView)
            .alert(joinEventMessage ?? "Присоединение к мероприятию", isPresented: $showJoinEventAlert) {
                Button("OK") {}
            }
            .overlay {
                if isJoiningEvent {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                }
            }
            .onOpenURL { url in
                logger.info("App received URL: \(url.absoluteString)")
                
                if url.absoluteString.starts(with: googleCallbackURI) {
                    logger.info("Processing Google OAuth callback URL")
                } else if url.absoluteString.starts(with: "itsplanned://reset-password") {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let tokenItem = components.queryItems?.first(where: { $0.name == "token" }),
                       let token = tokenItem.value {
                        logger.info("Processing password reset URL with token")
                        resetPasswordToken = token
                        showResetPasswordView = true
                    } else {
                        logger.warning("Invalid password reset URL: \(url.absoluteString)")
                    }
                } else if url.absoluteString.starts(with: "itsplanned://event/join") {
                    handleEventJoinURL(url)
                } else {
                    logger.warning("Received unrecognized URL: \(url.absoluteString)")
                }
            }
        }
    }
    
    private func configureNotifications() {
        NotificationManager.shared.requestPermissions { granted in
            if granted {
                logger.info("Notification permissions granted via NotificationManager")
            } else {
                logger.warning("Notification permissions denied via NotificationManager")
            }
        }
    }
    
    private func handleEventJoinURL(_ url: URL) {
        logger.info("Processing event join URL: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            logger.warning("Invalid event join URL: missing or invalid 'code' parameter")
            joinEventMessage = "Недействительная ссылка приглашения"
            showJoinEventAlert = true
            return
        }
        
        Task {
            await MainActor.run {
                isJoiningEvent = true
            }
            
            let result = await JoinEventService.shared.joinEvent(code: code)
            
            await MainActor.run {
                isJoiningEvent = false
                joinEventMessage = result.success ? "Вы успешно присоединились к мероприятию" : result.message
                showJoinEventAlert = true
                
                if result.success {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await eventViewModel.fetchEvents()
                    }
                }
            }
        }
    }
}

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
