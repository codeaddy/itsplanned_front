import SwiftUI
import Inject

struct ForgotPasswordView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AuthViewModel()
    @State private var email: String
    @State private var showSuccess = false
    
    init(email: String) {
        _email = State(initialValue: email)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Восстановление пароля")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Введите email, указанный при регистрации. Мы отправим вам инструкции по восстановлению пароля.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    HStack {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(viewModel.isLoading)
                        
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    Task {
                        await viewModel.resetPassword(email: email)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Отправить")
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
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            })
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
                    dismiss()
                }
            } message: {
                Text("Инструкции по восстановлению пароля отправлены на ваш email")
            }
            .onChange(of: viewModel.isPasswordResetSuccessful) { success in
                if success {
                    showSuccess = true
                    viewModel.isPasswordResetSuccessful = false
                }
            }
            .enableInjection()
        }
    }
}

#Preview {
    ForgotPasswordView(email: "")
} 
