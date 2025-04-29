import SwiftUI
import Inject

struct EventTasksView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: EventTasksViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedTask: TaskResponse? = nil
    @State private var showTaskDetail = false
    let eventId: Int
    let eventName: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.primary)
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Text("Задачи")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "arrow.left")
                    .foregroundColor(.clear)
                    .font(.system(size: 20))
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if viewModel.tasks.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checklist")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Нет задач")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Добавьте задачи для этого события")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        viewModel.startAddingTask()
                    }) {
                        Text("Добавить задачу")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.tasks, id: \.id) { task in
                            TaskCardView(
                                task: task,
                                isCurrentUserAssigned: viewModel.isCurrentUserAssigned(to: task),
                                onToggleAssignment: {
                                    Task {
                                        await viewModel.toggleTaskAssignment(taskId: task.id)
                                    }
                                },
                                onToggleCompletion: {
                                    Task {
                                        await viewModel.toggleTaskCompletion(taskId: task.id)
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedTask = task
                                showTaskDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                viewModel.startAddingTask()
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Создать")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 150, height: 50)
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(radius: 2)
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $viewModel.isAddingTask) {
            AddTaskView(
                taskTitle: $viewModel.newTaskTitle,
                onSave: {
                    Task {
                        await viewModel.createTask(eventId: eventId)
                    }
                },
                onCancel: {
                    viewModel.cancelAddingTask()
                }
            )
        }
        .sheet(isPresented: $showTaskDetail, onDismiss: {
            Task {
                do {
                    try await viewModel.fetchTasks(eventId: eventId)
                } catch {
                    print("Error refreshing tasks after detail view: \(error)")
                    DispatchQueue.main.async {
                        viewModel.error = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
        }) {
            if let task = selectedTask {
                NavigationView {
                    ZStack {
                        TaskDetailView(
                            task: task,
                            isCurrentUserAssigned: viewModel.isCurrentUserAssigned(to: task),
                            isEventCreator: viewModel.isEventCreator,
                            onToggleAssignment: {
                                Task {
                                    await viewModel.toggleTaskAssignment(taskId: task.id)
                                    selectedTask = viewModel.tasks.first(where: { $0.id == task.id })
                                }
                            },
                            onToggleCompletion: {
                                Task {
                                    await viewModel.toggleTaskCompletion(taskId: task.id)
                                    selectedTask = viewModel.tasks.first(where: { $0.id == task.id })
                                }
                            },
                            onUpdateTask: { title, description, budget, points in
                                let result = await viewModel.updateTask(taskId: task.id, title: title, description: description, budget: budget, points: points)
                                if result {
                                    selectedTask = viewModel.tasks.first(where: { $0.id == task.id })
                                }
                                return result
                            }
                        )
                    }
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Ошибка"),
                message: Text(viewModel.error ?? "Неизвестная ошибка"),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarHidden(true)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            Task {
                print("EventTasksView appeared, loading tasks...")
                do {
                    try await viewModel.fetchTasks(eventId: eventId)
                } catch {
                    print("Error loading tasks in EventTasksView: \(error)")
                    if viewModel.error == nil {
                        viewModel.error = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
        }
        .enableInjection()
    }
}

struct TaskCardView: View {
    let task: TaskResponse
    let isCurrentUserAssigned: Bool
    let onToggleAssignment: () -> Void
    let onToggleCompletion: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                if task.assignedTo != nil {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(isCurrentUserAssigned ? "Вы" : "ДС")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            )
                        
                        Text("Исполнитель: \(isCurrentUserAssigned ? "Вы" : "Джон Сноу")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Нет исполнителя")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                    .frame(width: 36, height: 36)
                
                Text("\(task.points)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.trailing, isCurrentUserAssigned && !task.isCompleted ? 0 : 8)
            
            Group {
                if task.isCompleted {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .onTapGesture {
                        onToggleCompletion()
                    }
                } else if task.assignedTo == nil {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.55, blue: 0.45))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .onTapGesture {
                        onToggleAssignment()
                    }
                } else if isCurrentUserAssigned {
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            onToggleCompletion()
                        }
                        
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.95, green: 0.55, blue: 0.45))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "person.badge.minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            onToggleAssignment()
                        }
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.8, blue: 0.3))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}

struct AddTaskView: View {
    @Binding var taskTitle: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о задаче")) {
                    TextField("Название задачи", text: $taskTitle)
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        onSave()
                    }
                    .disabled(taskTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let previewViewModel = EventTasksViewModel()
    
    previewViewModel.setCurrentUserId(1)
    previewViewModel.skipAPICallsForPreview()
    
    previewViewModel.tasks = [
        TaskResponse(
            id: 1,
            title: "Задача назначена мне",
            description: "Эта задача назначена текущему пользователю и не завершена",
            budget: 5000,
            points: 5,
            eventId: 1,
            assignedTo: 1,
            isCompleted: false
        ),
        TaskResponse(
            id: 2,
            title: "Задача без исполнителя",
            description: "Эта задача не назначена никому и может быть взята",
            budget: 3000,
            points: 6,
            eventId: 1,
            assignedTo: nil,
            isCompleted: false
        ),
        TaskResponse(
            id: 3,
            title: "Задача назначена другому",
            description: "Эта задача назначена другому пользователю",
            budget: 2000,
            points: 7,
            eventId: 1,
            assignedTo: 2,
            isCompleted: false
        ),
        TaskResponse(
            id: 4,
            title: "Завершенная задача",
            description: "Эта задача выполнена и может быть отменена",
            budget: 1000,
            points: 4,
            eventId: 1,
            assignedTo: 1,
            isCompleted: true
        )
    ]
    
    return EventTasksView(
        viewModel: previewViewModel,
        eventId: 1,
        eventName: "Тестовое событие"
    )
} 
