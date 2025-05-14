import SwiftUI
import Inject

struct TaskDetailView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    
    let task: TaskResponse
    let isCurrentUserAssigned: Bool
    let isEventCreator: Bool
    let onToggleAssignment: () -> Void
    let onToggleCompletion: () -> Void
    let onUpdateTask: (String, String?, Double?, Int?) async -> Bool
    let onDeleteTask: () -> Void
    
    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var isEditingBudget = false
    @State private var isEditingPoints = false
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedBudget: String
    @State private var editedPoints: String
    @State private var showingSaveConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = "Не удалось обновить задачу. Попробуйте еще раз."
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false
    
    init(
        task: TaskResponse,
        isCurrentUserAssigned: Bool,
        isEventCreator: Bool,
        onToggleAssignment: @escaping () -> Void,
        onToggleCompletion: @escaping () -> Void,
        onUpdateTask: @escaping (String, String?, Double?, Int?) async -> Bool,
        onDeleteTask: @escaping () -> Void
    ) {
        self.task = task
        self.isCurrentUserAssigned = isCurrentUserAssigned
        self.isEventCreator = isEventCreator
        self.onToggleAssignment = onToggleAssignment
        self.onToggleCompletion = onToggleCompletion
        self.onUpdateTask = onUpdateTask
        self.onDeleteTask = onDeleteTask
        
        _editedTitle = State(initialValue: task.title)
        _editedDescription = State(initialValue: task.description ?? "")
        _editedBudget = State(initialValue: task.budget != nil ? String(format: "%.0f", task.budget!) : "")
        _editedPoints = State(initialValue: String(task.points))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.primary)
                                .font(.system(size: 20))
                        }
                        
                        Spacer()
                        
                        Text("Детали задачи")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.left")
                            .foregroundColor(.clear)
                            .font(.system(size: 20))
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            if isEditingTitle {
                                HStack {
                                    TextField("Название задачи", text: $editedTitle)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Button(action: {
                                        saveTaskChanges()
                                    }) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Button(action: {
                                        isEditingTitle = false
                                        editedTitle = task.title
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.red)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(task.title)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(task.isCompleted ? .gray : .primary)
                                        .strikethrough(task.isCompleted)
                                    
                                    if isEventCreator {
                                        Button(action: {
                                            isEditingTitle = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Описание")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                if isEditingDescription {
                                    VStack(alignment: .trailing) {
                                        TextEditor(text: $editedDescription)
                                            .frame(minHeight: 100)
                                            .padding(4)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        
                                        HStack {
                                            Button(action: {
                                                saveTaskChanges()
                                            }) {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.green)
                                            }
                                            
                                            Button(action: {
                                                isEditingDescription = false
                                                editedDescription = task.description ?? ""
                                            }) {
                                                Image(systemName: "xmark")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                } else {
                                    HStack(alignment: .top) {
                                        Text(task.description?.isEmpty ?? true ? "Нет описания" : task.description!)
                                            .font(.body)
                                            .foregroundColor(task.description?.isEmpty ?? true ? .secondary : .primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Spacer()
                                        
                                        if isEventCreator {
                                            Button(action: {
                                                isEditingDescription = true
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                                .frame(width: 50, height: 50)
                            
                            if isEditingPoints {
                                VStack {
                                    TextField("Баллы", text: $editedPoints)
                                        .keyboardType(.numberPad)
                                        .frame(width: 30)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 2) {
                                        Button(action: {
                                            saveTaskChanges()
                                        }) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Button(action: {
                                            isEditingPoints = false
                                            editedPoints = String(task.points)
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            } else {
                                Text("\(task.points)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        if isEventCreator {
                                            isEditingPoints = true
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Исполнитель")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if task.assignedTo != nil {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(isCurrentUserAssigned ? "Вы" : "ДС")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isCurrentUserAssigned ? "Вы" : "Джон Сноу")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if isCurrentUserAssigned {
                                        Text("Вы назначены на эту задачу")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Другой пользователь работает над задачей")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("Задача пока не назначена никому")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Бюджет")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditingBudget {
                            HStack {
                                TextField("Бюджет", text: $editedBudget)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 8)
                                
                                Text("₽")
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    saveTaskChanges()
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                
                                Button(action: {
                                    isEditingBudget = false
                                    editedBudget = task.budget != nil ? String(format: "%.0f", task.budget!) : ""
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.red)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundColor(.blue)
                                
                                Text(task.budget != nil ? "\(Int(task.budget!)) ₽" : "Не указан")
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if isEventCreator {
                                    Button(action: {
                                        isEditingBudget = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Статус")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .orange)
                                .font(.system(size: 20))
                            
                            Text(task.isCompleted ? "Выполнено" : "Ждет выполнения")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    if isEventCreator {
                        Divider()
                        
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                
                                Text("Удалить задачу")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.vertical, 10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
            
            if isLoading {
                ZStack {
                    Color(.systemBackground).opacity(0.7)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Обновление...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 5)
                    )
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .navigationTitle("Детали задачи")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Изменения сохранены", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        }
        .alert("Ошибка", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Удаление задачи", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                onDeleteTask()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите удалить задачу? Это действие нельзя отменить.")
        }
        .enableInjection()
    }
    
    private func saveTaskChanges() {
        Task {
            isLoading = true
            
            var budgetValue: Double? = nil
            if !editedBudget.isEmpty {
                budgetValue = Double(editedBudget)
            }
            
            var pointsValue: Int? = nil
            if !editedPoints.isEmpty, let points = Int(editedPoints) {
                pointsValue = points
            }
            
            let description = editedDescription.isEmpty ? nil : editedDescription
            
            let success = await onUpdateTask(editedTitle, description, budgetValue, pointsValue)
            
            isLoading = false
            if success {
                isEditingTitle = false
                isEditingDescription = false
                isEditingBudget = false
                isEditingPoints = false
                
                showingSaveConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showingSaveConfirmation = false
                }
            } else {
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    let previewTasks = [
        TaskResponse(
            id: 1,
            title: "Задача назначена мне",
            description: "Подробное описание задачи с различными требованиями и деталями. Эта задача назначена текущему пользователю и не завершена.",
            budget: 5000,
            points: 5,
            eventId: 1,
            assignedTo: 1, // Assigned to current user
            isCompleted: false
        ),
        TaskResponse(
            id: 2,
            title: "Задача без исполнителя",
            description: "Эта задача не назначена никому и может быть взята.",
            budget: 3000,
            points: 6,
            eventId: 1,
            assignedTo: nil, // Not assigned
            isCompleted: false
        ),
        TaskResponse(
            id: 3,
            title: "Задача назначена другому",
            description: "Эта задача назначена другому пользователю.",
            budget: 2000,
            points: 7,
            eventId: 1,
            assignedTo: 2, // Assigned to another user
            isCompleted: false
        ),
        TaskResponse(
            id: 4,
            title: "Завершенная задача",
            description: "Эта задача выполнена и может быть отменена.",
            budget: 1000,
            points: 4,
            eventId: 1,
            assignedTo: 1, // Assigned to current user
            isCompleted: true
        )
    ]
    
    return NavigationView {
        TaskDetailView(
            task: previewTasks[0],
            isCurrentUserAssigned: true,
            isEventCreator: true,
            onToggleAssignment: {},
            onToggleCompletion: {},
            onUpdateTask: { _, _, _, _ in return true },
            onDeleteTask: {}
        )
    }
} 
