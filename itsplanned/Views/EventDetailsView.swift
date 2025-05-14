import SwiftUI
import Inject

extension EventResponse: Identifiable {}

struct EventDetailsView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventDetailsViewModel()
    
    @Binding var event: EventResponse
    @State private var currentEvent: EventResponse
    @State private var isInitiallyLoading = true
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var loadingAttempts = 0
    
    init(event: Binding<EventResponse>) {
        self._event = event
        self._currentEvent = State(initialValue: event.wrappedValue)
        print("EventDetailsView initialized for event ID: \(event.wrappedValue.id)")
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if isInitiallyLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("Загрузка...")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                    
                    Text("Попытка \(loadingAttempts)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    if loadingAttempts > 1 {
                        Button("Повторить") {
                            print("Manual retry requested")
                            startLoadingProcess()
                        }
                        .padding(.top, 24)
                        .foregroundColor(.blue)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 20))
                            }
                            
                            Spacer()
                            
                            Text("Детали мероприятия")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.left")
                                .foregroundColor(.clear)
                                .font(.system(size: 20))
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        if !viewModel.hasAccess {
                            VStack(spacing: 16) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                                
                                Text("У вас нет доступа к этому мероприятию")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                Text("Вы не являетесь участником этого мероприятия")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: { dismiss() }) {
                                    Text("Вернуться")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                        .padding(.horizontal, 40)
                                        .padding(.top, 20)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Название")
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                                if viewModel.isEditingName {
                                    HStack {
                                        TextField("Название", text: $viewModel.editedName)
                                            .padding(.vertical, 8)
                                        
                                        Button(action: {
                                            Task {
                                                let (success, updatedEvent) = await viewModel.saveEventEdits(eventId: currentEvent.id)
                                                if success && updatedEvent != nil {
                                                    currentEvent = updatedEvent!
                                                    updateParentEvent()
                                                }
                                            }
                                        }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                        
                                        Button(action: {
                                            viewModel.cancelEditing()
                                        }) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                } else {
                                    HStack {
                                        Text(currentEvent.name)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if viewModel.isOwner {
                                            Button(action: {
                                                viewModel.startEditingName(currentName: currentEvent.name)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                HStack {
                                    Text("Дата и время")
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                                
                                if viewModel.isEditingDateTime {
                                    HStack {
                                        DatePicker("", selection: $viewModel.editedDateTime)
                                            .labelsHidden()
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            Task {
                                                let (success, updatedEvent) = await viewModel.saveEventEdits(eventId: currentEvent.id)
                                                if success && updatedEvent != nil {
                                                    currentEvent = updatedEvent!
                                                    updateParentEvent()
                                                }
                                            }
                                        }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                        
                                        Button(action: {
                                            viewModel.cancelEditing()
                                        }) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                } else {
                                    HStack {
                                        Text(formattedDate(currentEvent.eventDateTime))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if viewModel.isOwner {
                                            Button(action: {
                                                viewModel.startEditingDateTime(currentDateTime: currentEvent.eventDateTime)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                if viewModel.isOwner {
                                    Button(action: {
                                        viewModel.showingTimeslotsView = true
                                    }) {
                                        Text("Подобрать время с Google Calendar")
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                    }
                                    .sheet(isPresented: $viewModel.showingTimeslotsView) {
                                        EventTimeslotsView(eventId: currentEvent.id, event: $currentEvent)
                                            .onDisappear {
                                                updateParentEvent()
                                            }
                                    }
                                }
                                
                                HStack {
                                    Text("Место проведения")
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                                
                                if viewModel.isEditingPlace {
                                    HStack {
                                        TextField("Место проведения", text: $viewModel.editedPlace)
                                            .padding(.vertical, 8)
                                        
                                        Button(action: {
                                            Task {
                                                let (success, updatedEvent) = await viewModel.saveEventEdits(eventId: currentEvent.id)
                                                if success && updatedEvent != nil {
                                                    currentEvent = updatedEvent!
                                                    updateParentEvent()
                                                }
                                            }
                                        }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                        
                                        Button(action: {
                                            viewModel.cancelEditing()
                                        }) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                } else {
                                    HStack {
                                        Text(currentEvent.place ?? "Не указано")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if viewModel.isOwner {
                                            Button(action: {
                                                viewModel.startEditingPlace(currentPlace: currentEvent.place)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                HStack {
                                    Text("Описание")
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                                
                                if viewModel.isEditingDescription {
                                    VStack {
                                        TextEditor(text: $viewModel.editedDescription)
                                            .frame(minHeight: 100)
                                            .padding(4)
                                        
                                        HStack {
                                            Spacer()
                                            
                                            Button(action: {
                                                Task {
                                                    let (success, updatedEvent) = await viewModel.saveEventEdits(eventId: currentEvent.id)
                                                    if success && updatedEvent != nil {
                                                        currentEvent = updatedEvent!
                                                        updateParentEvent()
                                                    }
                                                }
                                            }) {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.green)
                                            }
                                            
                                            Button(action: {
                                                viewModel.cancelEditing()
                                            }) {
                                                Image(systemName: "xmark")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                } else {
                                    HStack {
                                        Text(currentEvent.description ?? "Нет описания")
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        if viewModel.isOwner {
                                            Button(action: {
                                                viewModel.startEditingDescription(currentDescription: currentEvent.description)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Участники мероприятия")
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Spacer()
                                    
                                    VStack {
                                        NavigationLink(destination: ParticipantsDestinationView(eventId: currentEvent.id, eventName: currentEvent.name)) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.blue)
                                                    .frame(width: 80, height: 60)
                                                
                                                Text("\(viewModel.participants.count)")
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        Text("участников")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                
                                    Spacer(minLength: 40)
                                
                                    VStack {
                                        Button(action: {
                                            Task {
                                                await viewModel.generateAndCopyInviteLink(eventId: currentEvent.id)
                                            }
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.blue)
                                                    .frame(width: 80, height: 60)
                                                
                                                Image(systemName: "person.badge.plus")
                                                    .font(.title)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        Text("пригласить еще")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            VStack(spacing: 16) {
                                if viewModel.isEditingBudget {
                                    HStack {
                                        Image(systemName: "banknote")
                                            .foregroundColor(.gray)
                                        
                                        Text("Плановый бюджет: ")
                                            .foregroundColor(.primary)
                                        
                                        TextField("Бюджет", text: $viewModel.editedBudget)
                                            .keyboardType(.numberPad)
                                            .padding(.vertical, 8)
                                        
                                        Text("₽")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            Task {
                                                let (success, updatedEvent) = await viewModel.saveEventEdits(eventId: currentEvent.id)
                                                if success && updatedEvent != nil {
                                                    currentEvent = updatedEvent!
                                                    updateParentEvent()
                                                }
                                            }
                                        }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                        
                                        Button(action: {
                                            viewModel.cancelEditing()
                                        }) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal)
                                } else {
                                    HStack {
                                        Image(systemName: "banknote")
                                            .foregroundColor(.gray)
                                        
                                        Text("Плановый бюджет: \(formatBudget(currentEvent.initialBudget))₽")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if viewModel.isOwner {
                                            Button(action: {
                                                viewModel.startEditingBudget(currentBudget: currentEvent.initialBudget)
                                            }) {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            HStack {
                                Text("Уже потрачено: \(formatBudget(viewModel.spentBudget))₽")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "banknote")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.top, 5)
                            
                            VStack(spacing: 16) {
                                NavigationLink(destination: TasksDestinationView(eventId: currentEvent.id, eventName: currentEvent.name)) {
                                    HStack {
                                        Text("Задачи")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                            
                            VStack(spacing: 16) {
                                NavigationLink(destination: EventLeaderboardView(eventId: currentEvent.id, eventName: currentEvent.name)) {
                                    HStack {
                                        Text("Рейтинг участников")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                            
                            if viewModel.hasAccess && !viewModel.isOwner {
                                Button(action: {
                                    viewModel.showingLeaveConfirmation = true
                                }) {
                                    Text("Покинуть мероприятие")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                            
                            if viewModel.isOwner {
                                Divider()
                                
                                Button(action: {
                                    viewModel.showingDeleteConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                        
                                        Text("Удалить мероприятие")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.red)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .navigationBarHidden(true)
                .overlay(
                    viewModel.showShareLinkCopied ?
                    VStack {
                        Spacer()
                        
                        Text("Ссылка-приглашение успешно скопирована")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: viewModel.showShareLinkCopied)
                    : nil
                )
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
            }
        }
        .onAppear {
            print("EventDetailsView appeared for event: \(currentEvent.id)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                startLoadingProcess()
            }
        }
        .onDisappear {
            updateParentEvent()
            
            loadingTask?.cancel()
            loadingTask = nil
            
            print("EventDetailsView disappeared")
        }
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                if viewModel.errorMessage.contains("not a participant") {
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog("Удаление мероприятия", isPresented: $viewModel.showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                Task {
                    let success = await viewModel.deleteEvent(eventId: currentEvent.id)
                    if success {
                        dismiss()
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите удалить мероприятие? Это действие нельзя отменить и приведет к удалению всех задач мероприятия.")
        }
        .confirmationDialog("Покинуть мероприятие", isPresented: $viewModel.showingLeaveConfirmation, titleVisibility: .visible) {
            Button("Покинуть", role: .destructive) {
                Task {
                    let success = await viewModel.leaveEvent(eventId: currentEvent.id)
                    if success {
                        dismiss()
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите покинуть мероприятие? Вы всегда сможете присоединиться снова по пригласительной ссылке.")
        }
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            if isInitiallyLoading && loadingTask != nil {
                print("Loading timeout - resetting loading state")
                DispatchQueue.main.async {
                    isInitiallyLoading = false
                }
            }
        }
        .enableInjection()
    }
    
    func fetchLatestEventData() async throws {
        do {
            print("Starting fetchLatestEventData for event ID: \(currentEvent.id)")
            
            guard let token = await KeychainManager.shared.getToken() else {
                print("Token not available!")
                throw EventDetailError.unauthorized
            }
            print("Token obtained successfully")
            
            guard let url = URL(string: "\(APIConfig.baseURL)/events/\(currentEvent.id)") else {
                print("Invalid URL!")
                throw EventDetailError.invalidURL
            }
            print("Preparing request to: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            print("Sending request to fetch event details...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Response received!")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type!")
                throw EventDetailError.invalidResponse
            }
            
            print("Event Details Response Status: \(httpResponse.statusCode)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Event Details JSON: \(jsonString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("Successfully received 200 status code")
                if let eventResponse = try? JSONDecoder().decode(APIResponse<EventResponse>.self, from: data),
                   let updatedEvent = eventResponse.data {
                    print("Successfully decoded event data")
                    currentEvent = updatedEvent
                    updateParentEvent()
                    print("Event data updated!")
                } else {
                    print("Failed to decode event data!")
                    throw EventDetailError.apiError("Failed to decode event data")
                }
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                print("Access denied: \(httpResponse.statusCode)")
                viewModel.hasAccess = false
                throw EventDetailError.apiError("You are not authorized to view this event")
            } else {
                print("API error with status code: \(httpResponse.statusCode)")
                throw EventDetailError.apiError("Failed to fetch event details")
            }
        } catch {
            print("Error in fetchLatestEventData: \(error.localizedDescription)")
            viewModel.showError = true
            if let eventError = error as? EventDetailError {
                viewModel.errorMessage = eventError.message
            } else {
                viewModel.errorMessage = error.localizedDescription
            }
            
            throw error
        }
    }
    
    func formattedDate(_ dateString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: dateString) else {
            return "Неизвестная дата"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM yyyy, HH:mm"
        displayFormatter.locale = Locale(identifier: "ru_RU")
        return displayFormatter.string(from: date)
    }
    
    func formatBudget(_ budget: Double) -> String {
        return String(format: "%.0f", budget)
    }
    
    func updateParentEvent() {
        event = currentEvent
    }
    
    private func startLoadingProcess() {
        loadingTask?.cancel()
        loadingTask = nil
        
        isInitiallyLoading = true
        loadingAttempts += 1
        
        print("Starting loading process (attempt \(loadingAttempts)) for event ID: \(currentEvent.id)")
        
        loadingTask = Task {
            do {
                let taskID = UUID().uuidString.prefix(8)
                print("[\(taskID)] ===== STARTING LOADING PROCESS (Attempt \(loadingAttempts)) =====")
                print("[\(taskID)] Event ID: \(currentEvent.id)")
                print("[\(taskID)] Event Name: \(currentEvent.name)")
                
                try await Task.sleep(for: .milliseconds(300))
                
                if Task.isCancelled { 
                    print("[\(taskID)] Task cancelled during delay")
                    return 
                }
                
                print("[\(taskID)] Checking event access...")
                let hasAccess = await viewModel.checkEventAccess(eventId: currentEvent.id)
                print("[\(taskID)] Access check result: \(hasAccess)")
                
                if Task.isCancelled { 
                    print("[\(taskID)] Task cancelled after access check")
                    return 
                }
                
                if hasAccess {
                    print("[\(taskID)] Fetching event data...")
                    do {
                        try await fetchLatestEventData()
                        print("[\(taskID)] Event data fetched successfully")
                    } catch {
                        print("[\(taskID)] Error fetching event data: \(error)")
                    }
                    
                    if Task.isCancelled { 
                        print("[\(taskID)] Task cancelled after fetching event data")
                        return 
                    }
                    
                    if !Task.isCancelled {
                        print("[\(taskID)] Fetching additional data...")
                        
                        await withTaskGroup(of: Void.self) { group in
                            group.addTask {
                                print("[\(taskID)] Fetching participants...")
                                await viewModel.fetchParticipants(eventId: currentEvent.id)
                                print("[\(taskID)] Participants fetched")
                            }
                            
                            group.addTask {
                                print("[\(taskID)] Fetching budget info...")
                                await viewModel.fetchBudgetInfo(eventId: currentEvent.id)
                                print("[\(taskID)] Budget info fetched")
                            }
                            
                            group.addTask {
                                print("[\(taskID)] Fetching leaderboard...")
                                await viewModel.fetchLeaderboard(eventId: currentEvent.id)
                                print("[\(taskID)] Leaderboard fetched")
                            }
                            
                            for await _ in group { }
                        }
                        print("[\(taskID)] All additional data loaded")
                    }
                }
                
                if Task.isCancelled { 
                    print("[\(taskID)] Task cancelled before final state update")
                    return 
                }
                
                try await Task.sleep(for: .milliseconds(200))
                
                if !Task.isCancelled {
                    print("[\(taskID)] Setting isInitiallyLoading to false")
                    DispatchQueue.main.async {
                        print("[\(taskID)] Actually updating isInitiallyLoading now")
                        withAnimation {
                            isInitiallyLoading = false
                        }
                        print("[\(taskID)] isInitiallyLoading is now \(isInitiallyLoading)")
                    }
                }
                
                print("[\(taskID)] ===== LOADING PROCESS COMPLETED =====")
            } catch {
                print("Error during loading: \(error.localizedDescription)")
                
                if !Task.isCancelled {
                    DispatchQueue.main.async {
                        viewModel.showError = true
                        viewModel.errorMessage = error.localizedDescription
                        isInitiallyLoading = false
                        print("Set isInitiallyLoading to false due to error")
                    }
                }
            }
        }
    }
}

struct TasksDestinationView: View {
    let eventId: Int
    let eventName: String
    @StateObject private var viewModel = EventTasksViewModel()
    @State private var isInitiallyLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Ошибка загрузки")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            errorMessage = nil
                            isInitiallyLoading = true
                            try? await Task.sleep(for: .milliseconds(300))
                            await loadData()
                        }
                    }) {
                        Text("Повторить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .padding()
            } else if isInitiallyLoading {
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
                EventTasksView(
                    viewModel: viewModel,
                    eventId: eventId,
                    eventName: eventName
                )
            }
        }
        .task {
            await loadData()
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            print("TasksDestinationView disappeared")
        }
    }
    
    private func loadData() async {
        print("Starting to load tasks for event ID: \(eventId)")
        
        defer {
            DispatchQueue.main.async {
                isInitiallyLoading = false
            }
        }
        
        let userId = await KeychainManager.shared.getUserId() ?? 0
        viewModel.setCurrentUserId(userId)
        print("Set current user ID to: \(userId)")
        
        do {
            try await viewModel.fetchTasks(eventId: eventId)
            
            print("Successfully loaded \(viewModel.tasks.count) tasks")
            errorMessage = nil
        } catch {
            print("Error fetching tasks: \(error)")
            
            if let taskError = error as? TaskError {
                errorMessage = taskError.description
            } else {
                errorMessage = "Не удалось загрузить задачи: \(error.localizedDescription)"
            }
            
            viewModel.error = errorMessage
            viewModel.showError = true
        }
    }
}

#Preview {
    NavigationView {
        EventDetailsView(event: .constant(EventResponse(
            id: 1,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "Встреча коллег",
            description: "Обсуждение текущих проектов и планирование будущих задач. Встреча пройдет в конференц-зале на 3 этаже.",
            eventDateTime: ISO8601DateFormatter().string(from: Date()),
            place: "Офис компании",
            initialBudget: 5000,
            organizerId: 1
        )))
    }
} 
