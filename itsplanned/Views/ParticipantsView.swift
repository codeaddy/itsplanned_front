import SwiftUI
import Inject

struct ParticipantsView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ParticipantsViewModel()
    
    let eventId: Int
    let eventName: String
    @State private var isInitiallyLoading = true
    
    init(eventId: Int, eventName: String, preloadedViewModel: ParticipantsViewModel? = nil) {
        self.eventId = eventId
        self.eventName = eventName
        
        if let preloadedViewModel = preloadedViewModel {
            _viewModel = StateObject(wrappedValue: preloadedViewModel)
        }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && isInitiallyLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("Загрузка участников...")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
            } else {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 20))
                            }
                            
                            Spacer()
                            
                            Text("Участники")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.left")
                                .foregroundColor(.clear)
                                .font(.system(size: 20))
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        Text(eventName)
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Поиск участников", text: $viewModel.searchText)
                                .onChange(of: viewModel.searchText) { _ in
                                    viewModel.filterParticipants()
                                }
                            
                            if !viewModel.searchText.isEmpty {
                                Button(action: {
                                    viewModel.searchText = ""
                                    viewModel.filterParticipants()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Всего участников: \(viewModel.participants.count)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 10)
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    if viewModel.filteredParticipants.isEmpty {
                        if viewModel.searchText.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "person.3")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Участники не найдены")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text("Пока никто не присоединился к этому мероприятию")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Участники не найдены")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text("По запросу '\(viewModel.searchText)' ничего не найдено")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.filteredParticipants) { participant in
                                    ParticipantRow(participant: participant)
                                    
                                    Divider()
                                        .padding(.leading, 75)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !viewModel.participants.isEmpty {
                isInitiallyLoading = false
            }
        }
        .task {
            if viewModel.participants.isEmpty {
                await viewModel.fetchParticipants(eventId: eventId)
            }
            
            isInitiallyLoading = false
        }
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .enableInjection()
    }
}

struct ParticipantRow: View {
    let participant: Participant
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(getInitials(from: participant.name))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(participant.role)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        var initials = ""
        
        if let first = components.first, !first.isEmpty {
            initials.append(String(first.prefix(1)))
        }
        
        if components.count > 1, let last = components.last, !last.isEmpty {
            initials.append(String(last.prefix(1)))
        }
        
        return initials.uppercased()
    }
}

struct ParticipantsDestinationView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = ParticipantsViewModel()
    
    let eventId: Int
    let eventName: String
    @State private var isInitiallyLoading = true
    
    init(eventId: Int, eventName: String, preloadedViewModel: ParticipantsViewModel? = nil) {
        self.eventId = eventId
        self.eventName = eventName
        
        if let preloadedViewModel = preloadedViewModel {
            _viewModel = StateObject(wrappedValue: preloadedViewModel)
        }
    }
    
    var body: some View {
        ZStack {
            if isInitiallyLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("Загрузка...")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                }
            } else {
                ParticipantsView(
                    eventId: eventId,
                    eventName: eventName,
                    preloadedViewModel: viewModel.participants.isEmpty ? nil : viewModel
                )
            }
        }
        .onAppear {
            if !viewModel.participants.isEmpty {
                isInitiallyLoading = false
            }
        }
        .task {
            if !viewModel.participants.isEmpty {
                return
            }
            
            try? await Task.sleep(for: .milliseconds(300))
            isInitiallyLoading = false
        }
        .enableInjection()
    }
}

struct ParticipantsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            let viewModel = ParticipantsViewModel()
            viewModel.loadTestData()
            
            return ParticipantsView(
                eventId: 1,
                eventName: "Встреча коллег",
                preloadedViewModel: viewModel
            )
        }
    }
}

#Preview("Participants View") {
    NavigationView {
        let preloadedViewModel = ParticipantsViewModel()
        preloadedViewModel.loadTestData()
        
        return ParticipantsView(
            eventId: 1,
            eventName: "Встреча коллег",
            preloadedViewModel: preloadedViewModel
        )
    }
}

#Preview("Destination View") {
    NavigationView {
        let preloadedViewModel = ParticipantsViewModel()
        preloadedViewModel.loadTestData()
        
        return ParticipantsDestinationView(
            eventId: 1,
            eventName: "Встреча коллег",
            preloadedViewModel: preloadedViewModel
        )
    }
}

#Preview("Direct Test Data") {
    let testParticipants = [
        Participant(name: "Иван Иванов", role: "Организатор", avatar: nil),
        Participant(name: "Мария Петрова", role: "Участник", avatar: nil),
        Participant(name: "Алексей Смирнов", role: "Участник", avatar: nil),
        Participant(name: "Екатерина Соколова", role: "Участник", avatar: nil),
        Participant(name: "Дмитрий Козлов", role: "Участник", avatar: nil)
    ]
    
    let previewVM = ParticipantsViewModel()
    previewVM.participants = testParticipants
    previewVM.filteredParticipants = testParticipants
    
    return NavigationView {
        ParticipantsView(
            eventId: 1,
            eventName: "Встреча коллег",
            preloadedViewModel: previewVM
        )
    }
} 
