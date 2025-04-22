import SwiftUI
import Inject

struct StubView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Тестовая страница")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Email: \(UserDefaults.standard.email ?? "Не указан")")
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    await KeychainManager.shared.deleteToken()
                    UserDefaults.standard.email = nil
                    viewModel.isAuthenticated = false
                }
            }) {
                Text("Выйти")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
        .enableInjection()
    }
}

#Preview {
    StubView()
} 