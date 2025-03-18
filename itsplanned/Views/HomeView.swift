import SwiftUI
import Inject

struct HomeView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Добро пожаловать!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Вы успешно вошли в систему")
                    .foregroundColor(.secondary)
                
                // Display user's email
                if let email = UserDefaults.standard.email {
                    Text("Email: \(email)")
                        .foregroundColor(.secondary)
                } else {
                    Text("Email: Не указан")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.logout()
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
            .navigationTitle("Главная")
        }
        .enableInjection()
    }
}

#Preview {
    HomeView(viewModel: AuthViewModel())
} 