import SwiftUI
import Inject

struct MainTabView: View {
    @ObserveInjection var inject
    @EnvironmentObject var eventViewModel: EventViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            NavigationView {
                ChatListView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Чат")
            }
            
            NavigationView {
                EventsView(viewModel: eventViewModel)
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Мероприятия")
            }
            
            UserProfileView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Профиль")
                }
        }
        .accentColor(.blue)
        .enableInjection()
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
        .environmentObject(EventViewModel())
} 