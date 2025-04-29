import SwiftUI
import Inject
import SafariServices
import OSLog

private let logger = Logger(subsystem: "com.itsplanned", category: "UserProfile")

struct UserProfileView: View {
    @ObserveInjection var inject
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = UserProfileViewModel()
    @StateObject private var googleCalendarViewModel = GoogleCalendarViewModel()
    @State private var showingImagePicker = false
    @State private var isEditingUsername = false
    @State private var editedUsername = ""
    @State private var selectedImage: UIImage?
    @State private var showingSafari = false
    @State private var googleAuthURL: URL?
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    // Track active tasks to avoid memory leaks
    @State private var activeTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Профиль")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 120, height: 120)
                        
                        if let user = authViewModel.currentUser, let avatarURL = user.avatar, !avatarURL.isEmpty {
                            AsyncImage(url: URL(string: avatarURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                        
                        if profileViewModel.isImageLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    }
                    .onTapGesture {
                        // In future this will open the image picker
                        showingImagePicker = true
                    }
                    
                    if let user = authViewModel.currentUser {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(user.email)
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Изменить никнейм")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if isEditingUsername {
                        HStack {
                            TextField("Никнейм", text: $editedUsername)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                guard let userId = authViewModel.currentUser?.id else { return }
                                
                                activeTask?.cancel()
                                
                                activeTask = Task {
                                    if await profileViewModel.updateDisplayName(userId: userId, newName: editedUsername) {
                                        await authViewModel.refreshUserProfile()
                                    }
                                    await MainActor.run {
                                        isEditingUsername = false
                                    }
                                }
                            }) {
                                if profileViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(10)
                                } else {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .padding(10)
                                }
                            }
                            .disabled(profileViewModel.isLoading)
                        }
                    } else {
                        HStack {
                            if let user = authViewModel.currentUser {
                                Text(user.displayName)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                if let user = authViewModel.currentUser {
                                    editedUsername = user.displayName
                                }
                                isEditingUsername = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google Calendar")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 24)
                    
                    Button(action: {
                        if googleCalendarViewModel.isConnected {
                            // If already connected, trigger calendar import
                            importGoogleCalendar()
                        } else {
                            // If not connected, start the connection process
                            connectGoogleCalendar()
                        }
                    }) {
                        HStack {
                            Image(systemName: googleCalendarViewModel.isConnected ? "calendar.badge.clock" : "calendar")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                            
                            Text(googleCalendarViewModel.isConnected ? "Импортировать события из Google Calendar" : "Подключить Google Calendar")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                            
                            if googleCalendarViewModel.isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(googleCalendarViewModel.isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Выйти из аккаунта")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
            .background(Color.white)
            .sheet(isPresented: $showingImagePicker) {
                Text("Image picker will be implemented in the future")
                    .padding()
            }
            .sheet(isPresented: $showingSafari) {
                if let url = googleAuthURL {
                    SafariView(url: url, onFinish: {
                        showingSafari = false
                    })
                    .edgesIgnoringSafeArea(.all)
                }
            }
            .alert("Ошибка", isPresented: $profileViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(profileViewModel.error ?? "Произошла неизвестная ошибка")
            }
            .alert("Ошибка", isPresented: $googleCalendarViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(googleCalendarViewModel.error ?? "Произошла неизвестная ошибка при подключении Google Calendar")
            }
            .alert("Успешно", isPresented: $showingSuccessMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
            
            if profileViewModel.isLoading || googleCalendarViewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                if googleCalendarViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
        }
        .onOpenURL { url in
            handleGoogleAuthCallback(url: url)
        }
        .onAppear {
            Task {
                await googleCalendarViewModel.checkCalendarConnection()
            }
        }
        .enableInjection()
    }
    
    private func connectGoogleCalendar() {
        Task {
            await MainActor.run {
                googleCalendarViewModel.isLoading = true
            }
            
            if let url = await googleCalendarViewModel.getGoogleAuthURL() {
                await MainActor.run {
                    googleCalendarViewModel.isLoading = false
                    googleAuthURL = url
                    showingSafari = true
                }
            } else {
                await MainActor.run {
                    googleCalendarViewModel.isLoading = false
                }
            }
        }
    }
    
    private func importGoogleCalendar() {
        Task {
            let success = await googleCalendarViewModel.importCalendarEvents()
            if success {
                await MainActor.run {
                    showSuccessMessage("События успешно импортированы из Google Calendar")
                }
            }
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showingSuccessMessage = true
    }
    
    private func handleGoogleAuthCallback(url: URL) {
        logger.info("Received URL callback: \(url.absoluteString)")
        
        guard url.absoluteString.starts(with: googleCalendarViewModel.redirectURI) else {
            logger.error("URL does not match expected callback URI: \(url.absoluteString)")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            logger.error("Failed to extract auth code from callback URL: \(url.absoluteString)")
            return
        }
        
        logger.info("Extracted auth code from URL callback")
        
        Task {
            let success = await googleCalendarViewModel.handleCallback(code: code)
            
            await MainActor.run {
                showingSafari = false
                
                if success {
                    showSuccessMessage("Google Calendar успешно подключен")
                }
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onFinish: () -> Void = {}

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        safariViewController.preferredControlTintColor = .blue
        safariViewController.dismissButtonStyle = .close
        safariViewController.delegate = context.coordinator
        
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView
        
        init(_ parent: SafariView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.onFinish()
        }
    }
}

#Preview {
    let viewModel = AuthViewModel()
    let previewUser = UserResponse(
        id: 1,
        email: "itunoluwa@petra.africa",
        displayName: "Угар Угарович",
        bio: nil,
        avatar: nil,
        createdAt: "2023-01-01T00:00:00Z",
        updatedAt: "2023-01-01T00:00:00Z"
    )
    
    viewModel.setCurrentUserForPreview(previewUser)
    
    return UserProfileView(authViewModel: viewModel)
} 
