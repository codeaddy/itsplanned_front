//
//  itsplannedApp.swift
//  itsplanned
//
//  Created by Владислав Сизикин on 15.02.2025.
//

import SwiftUI
import Inject

@main
struct ItsplannedApp: App {
    @ObserveInjection var inject
    @StateObject private var authViewModel = AuthViewModel()
    
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
        }
    }
}
