import SwiftUI
import Inject

struct UserProfileView: View {
    @ObserveInjection var inject
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = UserProfileViewModel()
    @State private var showingImagePicker = false
    @State private var isEditingUsername = false
    @State private var editedUsername = ""
    @State private var selectedImage: UIImage?
    // Track active tasks to avoid memory leaks
    @State private var activeTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Profile header with title
                Text("Профиль")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                
                // Profile image with name and email
                VStack(spacing: 24) {
                    // Profile image
                    ZStack {
                        // Profile image background
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 120, height: 120)
                        
                        // Profile image
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
                        
                        // Show loading indicator when uploading image
                        if profileViewModel.isImageLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    }
                    .onTapGesture {
                        // In future this will open the image picker
                        showingImagePicker = true
                    }
                    
                    // User name and email
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
                
                // Username edit section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Изменить никнейм")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if isEditingUsername {
                        // Editing mode
                        HStack {
                            TextField("Никнейм", text: $editedUsername)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Button(action: {
                                guard let userId = authViewModel.currentUser?.id else { return }
                                
                                // Cancel any previous task
                                activeTask?.cancel()
                                
                                // Start a new task
                                activeTask = Task {
                                    if await profileViewModel.updateDisplayName(userId: userId, newName: editedUsername) {
                                        // Refresh user profile after successful update
                                        await authViewModel.refreshUserProfile()
                                    }
                                    // Set editing mode to false on main thread
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
                        // Display mode with edit button
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
                
                Spacer()
                
                // Logout button
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
            .alert("Ошибка", isPresented: $profileViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(profileViewModel.error ?? "Произошла неизвестная ошибка")
            }
            
            // Show loading overlay
            if profileViewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
            }
        }
        // Cancel any active tasks when the view disappears
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
        }
        .enableInjection()
    }
}

#Preview {
    // Create a mock user for preview
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
    
    // Set the currentUser property using the method
    viewModel.setCurrentUserForPreview(previewUser)
    
    return UserProfileView(authViewModel: viewModel)
} 