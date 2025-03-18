import SwiftUI
import Inject

struct EventsView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: EventViewModel
    @State private var showingCreateEvent = false
    
    // Simplified modal state - we'll only use a single piece of state
    @State private var selectedEvent: EventResponse? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Мероприятия")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Текущие")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.events.filter { isUpcoming($0) }, id: \.id) { event in
                            EventRowView(
                                event: event,
                                status: isNow(event) ? "Сейчас" : "Скоро",
                                isUpcoming: true
                            ) {
                                print("Tapped on CURRENT event: \(event.id) - \(event.name)")
                                // Directly set the selected event
                                selectedEvent = event
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Прошедшие")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.events.filter { !isUpcoming($0) }, id: \.id) { event in
                            EventRowView(
                                event: event,
                                status: "Прошел",
                                isUpcoming: false
                            ) {
                                print("Tapped on PAST event: \(event.id) - \(event.name)")
                                // Directly set the selected event
                                selectedEvent = event
                            }
                        }
                    }
                }
            }
            .padding(.top)
            .padding(.bottom, 80)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showingCreateEvent = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Создать")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(20)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .refreshable {
            await viewModel.fetchEvents()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Text(viewModel.error ?? "")
        }
        .sheet(isPresented: $showingCreateEvent) {
            EventCreationView()
                .onDisappear {
                    Task {
                        await viewModel.fetchEvents()
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Use sheet presentation directly with the event
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                // Direct binding to the event
                EventDetailsView(event: Binding(
                    get: { event },
                    set: { updatedEvent in
                        if let index = viewModel.events.firstIndex(where: { $0.id == event.id }) {
                            viewModel.events[index] = updatedEvent
                            print("Event updated in viewModel: \(updatedEvent.id)")
                        }
                    }
                ))
                .id(event.id) // Force view recreation for new events
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.fetchEvents()
        }
        .enableInjection()
    }
    
    private func isUpcoming(_ event: EventResponse) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        guard let eventDate = dateFormatter.date(from: event.eventDateTime) else {
            return false
        }
        return eventDate > Date()
    }
    
    private func isNow(_ event: EventResponse) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        guard let eventDate = dateFormatter.date(from: event.eventDateTime) else {
            return false
        }
        let now = Date()
        return eventDate <= now && eventDate.addingTimeInterval(3600) > now // Consider "now" if within the next hour
    }
}

struct EventRowView: View {
    let event: EventResponse
    let status: String
    let isUpcoming: Bool
    let onDetailsTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.name)
                .font(.headline)
            
            HStack {
                Text(formattedDate)
                    .foregroundColor(.gray)
                Text("-")
                    .foregroundColor(.gray)
                Text(status)
                    .foregroundColor(isUpcoming ? .blue : .gray)
                
                Spacer()
                
                Button(action: onDetailsTap) {
                    Text("Детали")
                        .foregroundColor(isUpcoming ? .blue : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var formattedDate: String {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: event.eventDateTime) else {
            return "Неизвестная дата"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "E, d MMM"
        displayFormatter.locale = Locale(identifier: "ru_RU")
        return displayFormatter.string(from: date)
    }
}

extension EventViewModel {
    static var preview: EventViewModel {
        let viewModel = EventViewModel()
        
        // Create sample events
        let currentEvent = EventResponse(
            id: 1,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "Встреча коллег",
            description: "Обсуждение текущих проектов",
            eventDateTime: ISO8601DateFormatter().string(from: Date()),
            place: "Офис компании",
            initialBudget: 5000,
            organizerId: 1
        )
        
        let upcomingEvent1 = EventResponse(
            id: 2,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "Мастер-класс по ивент-менеджменту",
            description: "Узнайте все о планировании мероприятий",
            eventDateTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 3600)),
            place: "Конференц-зал",
            initialBudget: 15000,
            organizerId: 1
        )
        
        let upcomingEvent2 = EventResponse(
            id: 3,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "Ретро вечеринка 80-ые с Кириллом",
            description: "Вечер в стиле диско",
            eventDateTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(2 * 24 * 3600)),
            place: "Клуб Retro",
            initialBudget: 25000,
            organizerId: 1
        )
        
        let pastEvent1 = EventResponse(
            id: 4,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "XXI Всемирная математическая олимпиада",
            description: "Международное соревнование по математике",
            eventDateTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-24 * 3600)),
            place: "Университет",
            initialBudget: 100000,
            organizerId: 1
        )
        
        let pastEvent2 = EventResponse(
            id: 5,
            createdAt: "2024-03-16T10:00:00Z",
            updatedAt: "2024-03-16T10:00:00Z",
            name: "Конференция iOS разработчиков",
            description: "Ежегодная встреча iOS сообщества",
            eventDateTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2 * 24 * 3600)),
            place: "IT-центр",
            initialBudget: 75000,
            organizerId: 1
        )
        
        // Set the events in the view model
        viewModel.events = [currentEvent, upcomingEvent1, upcomingEvent2, pastEvent1, pastEvent2]
        
        return viewModel
    }
}

#Preview {
    NavigationView {
        EventsView(viewModel: .preview)
    }
} 