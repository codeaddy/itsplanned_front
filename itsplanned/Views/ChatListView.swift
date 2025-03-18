import SwiftUI
import Inject

struct ChatListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedChatId: UUID? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Чаты")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        createAndNavigateToNewChat()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing)
                }
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                if viewModel.chatThreads.isEmpty {
                    // Empty state
                    EmptyChatsView(onNewChat: {
                        createAndNavigateToNewChat()
                    })
                } else {
                    // Chat list
                    List {
                        ForEach(viewModel.chatThreads) { thread in
                            Button(action: {
                                selectedChatId = thread.id
                            }) {
                                ChatThreadRow(thread: thread)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete { indexSet in
                            viewModel.chatThreads.remove(atOffsets: indexSet)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: selectedChatId.map { id in
                        LazyView(
                            ChatView(
                                chatId: id,
                                title: viewModel.getChatTitle(for: id),
                                viewModel: viewModel
                            )
                        )
                    },
                    isActive: Binding(
                        get: { selectedChatId != nil },
                        set: { if !$0 { selectedChatId = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .enableInjection()
    }
    
    // Create a new chat and navigate to it directly
    private func createAndNavigateToNewChat() {
        let newChatId = viewModel.createNewChat()
        selectedChatId = newChatId
    }
}

// Separate component for empty state
struct EmptyChatsView: View {
    let onNewChat: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("У вас пока нет чатов")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Нажмите на кнопку «+» вверху, чтобы начать новый чат с ассистентом")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onNewChat) {
                HStack {
                    Image(systemName: "plus")
                    Text("Новый чат")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(width: 200)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
}

// LazyView for deferred loading
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

struct ChatThreadRow: View {
    let thread: ChatThread
    
    // Cache for formatted date to avoid recalculation
    private var formattedDate: String {
        thread.shortFormattedDate
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar or icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "bubble.left.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
            }
            
            // Chat details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(thread.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ChatListView()
} 