import SwiftUI
import Inject

struct AuthView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isRegistering = false
    @State private var showForgotPassword = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isRegistering ? "Давайте знакомиться" : "Добро пожаловать")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                // Email field
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
                
                HStack {
                    SecureField("Пароль", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .disabled(viewModel.isLoading)
                    
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if isRegistering {
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
            }
            
            if !isRegistering {
                Button("Забыли пароль?") {
                    showForgotPassword = true
                }
                .foregroundColor(.blue)
                .disabled(viewModel.isLoading)
            }
            
            Button(action: {
                Task {
                    if isRegistering {
                        await viewModel.register(email: email, password: password, confirmPassword: confirmPassword)
                    } else {
                        await viewModel.login(email: email, password: password)
                    }
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isRegistering ? "Зарегистрироваться" : "Войти")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(viewModel.isLoading)
            
            Button(action: {
                withAnimation {
                    isRegistering.toggle()
                    password = ""
                    confirmPassword = ""
                    viewModel.error = nil
                }
            }) {
                Text(isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email)
        }
        .onChange(of: viewModel.isAuthenticated) { newValue in
            if newValue {
                email = ""
                password = ""
                confirmPassword = ""
            }
        }
        .enableInjection()
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
} 
