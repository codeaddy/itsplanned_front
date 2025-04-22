import SwiftUI
import Inject

struct EventLeaderboardView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventLeaderboardViewModel()
    
    let eventId: Int
    let eventName: String
    
    @State private var isInitiallyLoading = true
    @State private var loadingTask: Task<Void, Never>? = nil
    
    // Added initializer for Preview
    init(eventId: Int, eventName: String, previewData: [LeaderboardUser]? = nil, currentUserPosition: Int? = nil, currentUserEntry: LeaderboardUser? = nil) {
        self.eventId = eventId
        self.eventName = eventName
        
        // If preview data is provided, inject it
        if let previewData = previewData {
            _viewModel = StateObject(wrappedValue: {
                let vm = EventLeaderboardViewModel()
                vm.leaderboardUsers = previewData
                if let currentUserPosition = currentUserPosition {
                    vm.currentUserPosition = currentUserPosition
                }
                if let currentUserEntry = currentUserEntry {
                    vm.currentUserEntry = currentUserEntry
                }
                return vm
            }())
            _isInitiallyLoading = State(initialValue: false)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Loading state
            if isInitiallyLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Загрузка...")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with back button
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 20))
                            }
                            
                            Spacer()
                            
                            Text("Рейтинг участников")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            // Invisible element to balance the header
                            Image(systemName: "arrow.left")
                                .foregroundColor(.clear)
                                .font(.system(size: 20))
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                        
                        if viewModel.leaderboardUsers.isEmpty {
                            // Show empty state
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Рейтинг пуст")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Никто еще не заработал баллы в этом мероприятии")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(height: 400)
                        } else {
                            // Top 3 podium section
                            topThreePodium
                                .padding(.bottom, 40)
                            
                            // Full leaderboard list
                            leaderboardList
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .onAppear {
            print("EventLeaderboardView appeared")
            // Start loading data
            startLoadingProcess()
        }
        .onChange(of: viewModel.leaderboardUsers.count) { newCount in
            print("leaderboardUsers count changed: \(newCount) items")
        }
        .onDisappear {
            print("EventLeaderboardView disappeared")
            // Clean up when view disappears
            loadingTask?.cancel()
            loadingTask = nil
        }
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .enableInjection()
    }
    
    // Top 3 participants podium display
    private var topThreePodium: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Second place
            if viewModel.leaderboardUsers.count >= 2 {
                let user = viewModel.leaderboardUsers[1]
                participantPodiumView(
                    position: 2,
                    name: user.displayName,
                    score: Int(user.score),
                    avatar: user.avatar
                )
            } else {
                Spacer()
                    .frame(width: 80)
            }
            
            // First place (center, taller, with crown)
            if !viewModel.leaderboardUsers.isEmpty {
                let user = viewModel.leaderboardUsers[0]
                VStack(spacing: 0) {
                    // Crown image
                    Image(systemName: "crown.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.yellow)
                        .padding(.bottom, 2)
                    
                    // Profile image with position
                    ZStack {
                        // Avatar background circle
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.yellow, lineWidth: 3)
                            )
                        
                        // Avatar or placeholder
                        if let avatar = user.avatar, !avatar.isEmpty {
                            AsyncImage(url: URL(string: avatar)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                        
                        // Position number
                        ZStack {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 30, height: 30)
                            
                            Text("1")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 0, y: 35)
                    }
                    
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Show non-negative score for first place
                    Text("\(max(0, Int(user.score))) \(scoreEndingRussian(score: Int(user.score)))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
            } else {
                Spacer()
                    .frame(width: 100)
            }
            
            // Third place
            if viewModel.leaderboardUsers.count >= 3 {
                let user = viewModel.leaderboardUsers[2]
                participantPodiumView(
                    position: 3,
                    name: user.displayName,
                    score: Int(user.score),
                    avatar: user.avatar
                )
            } else {
                Spacer()
                    .frame(width: 80)
            }
        }
        .padding(.horizontal)
    }
    
    // Individual podium view for 2nd and 3rd place
    private func participantPodiumView(position: Int, name: String, score: Int, avatar: String?) -> some View {
        VStack(spacing: 0) {
            // Profile image with position
            ZStack {
                // Avatar background circle
                Circle()
                    .fill(position == 2 ? Color.blue.opacity(0.2) : Color.orange.opacity(0.3))
                    .frame(width: 70, height: 70)
                
                // Avatar or placeholder
                if let avatar = avatar, !avatar.isEmpty {
                    AsyncImage(url: URL(string: avatar)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                
                // Position number
                ZStack {
                    Circle()
                        .fill(position == 2 ? Color.blue : Color.orange)
                        .frame(width: 25, height: 25)
                    
                    Text("\(position)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 0, y: 30)
            }
            
            Text(name)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 20)
            
            // Show non-negative score
            Text("\(max(0, score)) \(scoreEndingRussian(score: score))")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // Full leaderboard list
    private var leaderboardList: some View {
        VStack(spacing: 0) {
            // List of all participants
            ForEach(viewModel.leaderboardUsers.prefix(3)) { user in
                leaderboardRow(user: user, highlight: user.position <= 3)
            }
            
            // If current user is not in top 3, show them separately
            if let currentUser = viewModel.currentUserEntry, currentUser.position > 3 {
                // Spacer with line to visually separate if user is not in top 3
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text("•••")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    
                    // Current user row
                    leaderboardRow(user: currentUser, highlight: false, isCurrentUser: true)
                }
            }
        }
    }
    
    // Individual leaderboard row
    private func leaderboardRow(user: LeaderboardUser, highlight: Bool, isCurrentUser: Bool = false) -> some View {
        HStack(spacing: 15) {
            // Position indicator
            HStack(spacing: 5) {
                if user.position <= 3 {
                    // For top 3, show a green arrow up
                    Image(systemName: "arrow.up")
                        .foregroundColor(.green)
                        .font(.caption)
                } else if isCurrentUser {
                    // For current user outside top 3, show a dash
                    Image(systemName: "minus")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                
                Text("\(user.position)")
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .primary : .gray)
            }
            .frame(width: 30, alignment: .leading)
            
            // User avatar
            ZStack {
                // Avatar background
                Circle()
                    .fill(avatarBackgroundColor(position: user.position))
                    .frame(width: 40, height: 40)
                
                if let avatar = user.avatar, !avatar.isEmpty {
                    AsyncImage(url: URL(string: avatar)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // User name
            Text(user.displayName)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Score with proper Russian noun ending
            Text("\(max(0, Int(user.score))) \(scoreEndingRussian(score: Int(user.score)))")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(rowBackgroundColor(position: user.position, isCurrentUser: isCurrentUser))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    // Helper function to get proper Russian word ending for points
    private func scoreEndingRussian(score: Int) -> String {
        let points = max(0, score)
        
        let lastDigit = points % 10
        let lastTwoDigits = points % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 19 {
            return "баллов"
        }
        
        switch lastDigit {
        case 1:
            return "балл"
        case 2, 3, 4:
            return "балла"
        default:
            return "баллов"
        }
    }
    
    // Background color for different positions in the list
    private func rowBackgroundColor(position: Int, isCurrentUser: Bool) -> Color {
        if position == 1 {
            return Color.yellow.opacity(0.2)
        } else if position == 2 {
            return Color(.systemGray6)
        } else if position == 3 {
            return Color.orange.opacity(0.2)
        } else if isCurrentUser {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray6)
        }
    }
    
    // Avatar background color based on position
    private func avatarBackgroundColor(position: Int) -> Color {
        if position == 1 {
            return Color.yellow.opacity(0.3)
        } else if position == 2 {
            return Color.blue.opacity(0.2)
        } else if position == 3 {
            return Color.orange.opacity(0.3)
        } else {
            return Color(.systemGray5)
        }
    }
    
    // Start the loading process
    private func startLoadingProcess() {
        print("Starting leaderboard loading process")
        // Cancel any previous task
        loadingTask?.cancel()
        loadingTask = nil
        
        // Set loading state
        isInitiallyLoading = true
        
        // Create a new loading task
        loadingTask = Task {
            do {
                print("Fetching leaderboard data for event ID: \(eventId)")
                await viewModel.fetchLeaderboard(eventId: eventId)
                
                // Short delay to ensure smooth UI transition
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    print("Loading completed, leaderboard has \(viewModel.leaderboardUsers.count) entries")
                    isInitiallyLoading = false
                }
            } catch {
                print("Error loading leaderboard: \(error)")
                await MainActor.run {
                    isInitiallyLoading = false
                }
            }
        }
    }
}

#Preview {
    // Create sample users
    let sampleUsers = [
        LeaderboardUser(id: 0, userId: 1, displayName: "Максим", score: 200, position: 1, avatar: nil),
        LeaderboardUser(id: 1, userId: 2, displayName: "Алексей", score: 150, position: 2, avatar: nil),
        LeaderboardUser(id: 2, userId: 3, displayName: "Екатерина", score: 100, position: 3, avatar: nil),
        LeaderboardUser(id: 3, userId: 12, displayName: "Мария", score: 75, position: 12, avatar: nil)
    ]
    
    // Return view with preview data
    return EventLeaderboardView(
        eventId: 1, 
        eventName: "Встреча команды",
        previewData: sampleUsers,
        currentUserPosition: 12,
        currentUserEntry: sampleUsers.last
    )
} 