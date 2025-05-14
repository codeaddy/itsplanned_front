import SwiftUI
import Inject

struct ResetPasswordView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showSuccess = false
    @Environment(\.presentationMode) private var presentationMode
    
    let token: String
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Введите новый пароль")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Пожалуйста, придумайте новый надежный пароль для вашего аккаунта.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    HStack {
                        SecureField("Новый пароль", text: $password)
                            .textContentType(.newPassword)
                            .disabled(viewModel.isLoading)
                        
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    HStack {
                        SecureField("Подтвердите пароль", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .disabled(viewModel.isLoading)
                        
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    if password != confirmPassword {
                        viewModel.error = .passwordMismatch
                        return
                    }
                    
                    Task {
                        await viewModel.submitNewPassword(token: token, password: password)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Сохранить")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .disabled(viewModel.isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Alert(
                    title: Text("Ошибка"),
                    message: Text(viewModel.error?.message ?? "Неизвестная ошибка"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Успешно", isPresented: $showSuccess) {
                Button("OK") {
                    self.presentationMode.wrappedValue.dismiss()
                    onDismiss?()
                }
            } message: {
                Text("Ваш пароль успешно изменен. Теперь вы можете войти в систему с новым паролем.")
            }
            .onChange(of: viewModel.isPasswordResetSuccessful) { success in
                if success {
                    showSuccess = true
                    viewModel.isPasswordResetSuccessful = false
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isAuthenticated },
                set: { _ in }
            )) {
                MainTabView(authViewModel: viewModel)
                    .environmentObject(EventViewModel())
            }
            .enableInjection()
        }
    }
}

#Preview {
    ResetPasswordView(token: "example-token")
        .environmentObject(AuthViewModel())
} 