import SwiftUI
import Inject

struct EventTimeslotsView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = EventTimeslotsViewModel()
    
    let eventId: Int
    @Binding var event: EventResponse
    
    @State private var loadingTask: Task<Void, Never>? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .font(.system(size: 22))
                            .frame(width: 30, height: 30)
                    }
                    
                    Spacer()
                    
                    Text("Выберите время")
                        .font(.headline)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                            .frame(width: 24)
                        
                        Spacer()
                        
                        DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: viewModel.date) { _ in
                                Task { await viewModel.fetchTimeslots(eventId: eventId) }
                            }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("С")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("До")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18))
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .frame(width: 80)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 18))
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .frame(width: 80)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundColor(.orange)
                                .font(.system(size: 18))
                            
                            Text("Продолжительность:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.durationMins) мин")
                                .font(.subheadline.bold())
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("30")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(viewModel.durationMins) },
                                set: { viewModel.durationMins = Int($0) }
                            ), in: 30...360, step: 30)
                            .tint(.orange)
                            
                            Text("360")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isRefreshing = true
                            }
                            Task { 
                                await viewModel.fetchTimeslots(eventId: eventId) 
                                withAnimation {
                                    isRefreshing = false
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                Text("Обновить")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                        
                        Button {
                            Task { await viewModel.fetchTimeslots(eventId: eventId) }
                        } label: {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Применить")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .padding(.bottom, 16)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 1)
                    
                    VStack {
                        Text("Доступные временные слоты")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                        
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                            Spacer()
                        } else if viewModel.timeslots.isEmpty {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("Нет доступных временных слотов")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Попробуйте изменить параметры поиска")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            Spacer()
                        } else {
                            CompactBubblesLayout(
                                timeslots: viewModel.timeslots,
                                selectedTimeslot: $viewModel.selectedTimeslot
                            )
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
                
                Button {
                    Task {
                        let (success, updatedEvent) = await viewModel.updateEventTime(eventId: eventId)
                        if success && updatedEvent != nil {
                            event = updatedEvent!
                            dismiss()
                        }
                    }
                } label: {
                    Text("Сохранить")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.selectedTimeslot != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
                .disabled(viewModel.selectedTimeslot == nil)
            }
        }
        .preferredColorScheme(.light)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Ошибка"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            startLoadingProcess()
        }
        .enableInjection()
    }
    
    private func startLoadingProcess() {
        loadingTask?.cancel()
        
        loadingTask = Task {
            await viewModel.fetchTimeslots(eventId: eventId)
        }
    }
}

struct CompactBubblesLayout: View {
    let timeslots: [TimeslotSuggestion]
    @Binding var selectedTimeslot: TimeslotSuggestion?
    
    @State private var calculatedLayout: [(timeslot: TimeslotSuggestion, position: CGPoint, size: CGFloat)] = []
    @State private var containerSize: CGSize = .zero
    
    private func calculateSizes() -> [CGFloat] {
        let minBusyCount = timeslots.map { $0.busyCount }.min() ?? 0
        let maxBusyCount = max(1, timeslots.map { $0.busyCount }.max() ?? 1)
        
        return timeslots.map { timeslot in
            let sizeRange: (min: CGFloat, max: CGFloat) = (90, 110)
            let normalizedValue = 1.0 - Double(timeslot.busyCount - minBusyCount) / Double(max(1, maxBusyCount - minBusyCount))
            return sizeRange.min + (sizeRange.max - sizeRange.min) * normalizedValue
        }
    }
    
    private func createLayout(in size: CGSize) {
        let sizes = calculateSizes()
        var result: [(timeslot: TimeslotSuggestion, position: CGPoint, size: CGFloat)] = []
        
        let sortedIndices = sizes.indices.sorted { sizes[$0] > sizes[$1] }
        
        guard size.width > 0, size.height > 0 else { return }
        
        let padding: CGFloat = 10
        let maxAttempts = 30
        
        for index in sortedIndices {
            let timeslot = timeslots[index]
            let bubbleSize = sizes[index]
            let radius = bubbleSize / 2
            
            var bestPosition: CGPoint?
            var lowestOverlap = Double.infinity
            
            for _ in 0..<maxAttempts {
                let randomX = radius + padding + CGFloat.random(in: 0...(size.width - 2 * (radius + padding)))
                let randomY = radius + padding + CGFloat.random(in: 0...(size.height - 2 * (radius + padding)))
                let candidatePosition = CGPoint(x: randomX, y: randomY)
                
                let overlap = calculateOverlap(position: candidatePosition, radius: radius, with: result)
                
                if overlap < lowestOverlap {
                    lowestOverlap = overlap
                    bestPosition = candidatePosition
                }
                
                if lowestOverlap == 0 {
                    break
                }
            }
            
            if let position = bestPosition {
                result.append((timeslot: timeslot, position: position, size: bubbleSize))
            }
        }
        
        optimizeLayout(layout: &result, containerSize: size)
        
        calculatedLayout = result
    }
    
    private func calculateOverlap(position: CGPoint, radius: CGFloat, with existing: [(timeslot: TimeslotSuggestion, position: CGPoint, size: CGFloat)]) -> Double {
        var totalOverlap: Double = 0
        
        for item in existing {
            let existingRadius = item.size / 2
            let distance = sqrt(pow(position.x - item.position.x, 2) + pow(position.y - item.position.y, 2))
            let minDistance = radius + existingRadius + 6
            
            if distance < minDistance {
                totalOverlap += Double(minDistance - distance)
            }
        }
        
        let edgeDistance = min(
            position.x - radius,
            position.y - radius,
            containerSize.width - position.x - radius,
            containerSize.height - position.y - radius
        )
        
        if edgeDistance < 0 {
            totalOverlap += Double(-edgeDistance * 2)
        }
        
        return totalOverlap
    }
    
    private func optimizeLayout(layout: inout [(timeslot: TimeslotSuggestion, position: CGPoint, size: CGFloat)], containerSize: CGSize) {
        let iterations = 60
        let repulsionStrength: CGFloat = 0.7
        let attractionStrength: CGFloat = 0.01
        
        for _ in 0..<iterations {
            for i in layout.indices {
                var deltaX: CGFloat = 0
                var deltaY: CGFloat = 0
                let radiusI = layout[i].size / 2
                
                let leftForce = max(0, 28 - (layout[i].position.x - radiusI)) * 4
                let rightForce = max(0, 28 - (containerSize.width - layout[i].position.x - radiusI)) * 4
                let topForce = max(0, 28 - (layout[i].position.y - radiusI)) * 4
                let bottomForce = max(0, 28 - (containerSize.height - layout[i].position.y - radiusI)) * 4
                
                deltaX += leftForce
                deltaX -= rightForce
                deltaY += topForce
                deltaY -= bottomForce
                
                for j in layout.indices {
                    if i != j {
                        let radiusJ = layout[j].size / 2
                        let dx = layout[i].position.x - layout[j].position.x
                        let dy = layout[i].position.y - layout[j].position.y
                        let distance = sqrt(dx*dx + dy*dy)
                        let minDistance = radiusI + radiusJ + 12
                        
                        if distance < minDistance {
                            let force = repulsionStrength * (minDistance - distance) / distance
                            deltaX += dx * force
                            deltaY += dy * force
                        } else {
                            deltaX -= dx * attractionStrength
                            deltaY -= dy * attractionStrength
                        }
                    }
                }
                
                let damping: CGFloat = 0.8
                let newX = max(radiusI, min(containerSize.width - radiusI, layout[i].position.x + deltaX * damping))
                let newY = max(radiusI, min(containerSize.height - radiusI, layout[i].position.y + deltaY * damping))
                
                layout[i].position = CGPoint(x: newX, y: newY)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear.onAppear {
                    containerSize = geometry.size
                    createLayout(in: geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    containerSize = newSize
                    createLayout(in: newSize)
                }
                
                ForEach(calculatedLayout.indices, id: \.self) { index in
                    let item = calculatedLayout[index]
                    CompactTimeslotBubble(
                        time: item.timeslot.formattedTime(),
                        busyCount: item.timeslot.busyCount,
                        isSelected: selectedTimeslot?.slot == item.timeslot.slot,
                        size: item.size
                    )
                    .position(item.position)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTimeslot = item.timeslot
                        }
                    }
                }
            }
        }
        .frame(height: 300)
        .onAppear {
            createLayout(in: containerSize)
        }
    }
}

struct CompactTimeslotBubble: View {
    let time: String
    let busyCount: Int
    let isSelected: Bool
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color(.systemGray6))
                .frame(width: size, height: size)
            
            VStack(spacing: 2) {
                Text(time)
                    .font(.system(size: min(size/5, 18), weight: .medium))
                    .foregroundColor(isSelected ? .white : .black)
                
                HStack(spacing: 2) {
                    Text("\(busyCount)")
                        .font(.system(size: min(size/7, 13)))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: min(size/8, 11)))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EventTimeslotsView(eventId: 1, event: .constant(EventResponse(
        id: 1,
        createdAt: "2023-01-01T00:00:00Z",
        updatedAt: "2023-01-01T00:00:00Z",
        name: "Team Meeting",
        description: "Weekly team sync",
        eventDateTime: "2023-01-10T15:00:00Z",
        place: "Conference Room A",
        initialBudget: 0.0,
        organizerId: 1
    )))
} 
