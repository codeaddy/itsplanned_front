import SwiftUI
import Inject

struct EventCreationView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventCreationViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with improved padding
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Text("Новое мероприятие")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible element to balance the header
                Image(systemName: "xmark")
                    .foregroundColor(.clear)
                    .font(.system(size: 20))
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Name field
                    TextField("", text: $viewModel.title)
                        .placeholder(when: viewModel.title.isEmpty) {
                            Text("Название (обязательно)")
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    // Description field
                    ZStack(alignment: .topLeading) {
                        if viewModel.description.isEmpty {
                            Text("Описание")
                                .foregroundColor(Color(.systemGray))
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }
                        
                        TextEditor(text: $viewModel.description)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                    }
                    .frame(height: 120)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Date field
                    TextField("", text: .constant(""))
                        .disabled(true)
                        .placeholder(when: true) {
                            Text("Дата")
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Spacer()
                                DatePicker("", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.trailing, 16)
                            }
                        )
                    
                    // Place field
                    TextField("", text: $viewModel.place)
                        .placeholder(when: viewModel.place.isEmpty) {
                            Text("Место проведения")
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    // Budget field
                    TextField("", text: $viewModel.budget)
                        .placeholder(when: viewModel.budget.isEmpty) {
                            Text("Бюджет")
                                .foregroundColor(Color(.systemGray))
                        }
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "banknote")
                                .foregroundColor(Color(.systemGray2))
                                .padding(.trailing, 16),
                            alignment: .trailing
                        )
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Create button
            Button(action: {
                Task {
                    let success = await viewModel.createEvent()
                    if success {
                        dismiss()
                    }
                }
            }) {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Создать")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isValid ? Color.blue : Color.blue.opacity(0.5))
                .cornerRadius(25)
            }
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
        .enableInjection()
    }
}

// Extension for TextField placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    EventCreationView()
} 