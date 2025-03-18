import SwiftUI
import Inject

struct ChatView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var scrollToBottom = false
    
    let chatId: UUID
    let title: String
    
    init(chatId: UUID, title: String, viewModel: ChatViewModel) {
        self.chatId = chatId
        self.title = title
        self.viewModel = viewModel
        
        // Ensure we load the correct chat messages
        viewModel.loadChat(threadId: chatId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.primary)
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                Text(title)
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
            .padding(.bottom, 10)
            
            // Messages list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.currentMessages) { message in
                            ChatMessageView(message: message)
                                .id(message.id) // For scrolling
                        }
                        
                        // Invisible spacer view to scroll to
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                            .id("bottomID")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.currentMessages.count) { _ in
                    // Scroll to bottom when messages change
                    withAnimation {
                        scrollView.scrollTo("bottomID", anchor: .bottom)
                    }
                }
                .onAppear {
                    // Scroll to bottom when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollView.scrollTo("bottomID", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
                    // Message input field
                    ZStack(alignment: .leading) {
                        if viewModel.messageText.isEmpty {
                            Text("сообщение")
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.leading, 16)
                        }
                        
                        TextField("", text: $viewModel.messageText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .focused($isInputFocused)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    
                    // Send button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            sendMessage()
                        }
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.blue))
                    }
                    .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .onAppear {
            // Auto-focus the text field after a short delay to ensure the view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
        .enableInjection()
    }
    
    private func sendMessage() {
        viewModel.sendMessage(threadId: chatId, content: viewModel.messageText)
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer()
                
                // User message - blue bubble on the right
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(ChatBubbleShape(isFromUser: true))
                    .overlay(
                        // Time display at the bottom left
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .offset(y: 18),
                        alignment: .bottomLeading
                    )
                    .padding(.bottom, 15) // Add padding for the timestamp
            } else {
                // Assistant avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Text("👨‍💻")
                        .font(.system(size: 18))
                }
                
                // Assistant message - gray bubble on the left
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(ChatBubbleShape(isFromUser: false))
                    .overlay(
                        // Time display at the bottom right
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .offset(y: 18),
                        alignment: .bottomTrailing
                    )
                    .padding(.bottom, 15) // Add padding for the timestamp
                
                Spacer()
            }
        }
    }
}

// Custom chat bubble shape
struct ChatBubbleShape: Shape {
    var isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isFromUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let viewModel = ChatViewModel()
    let chatId = viewModel.chatThreads.first?.id ?? UUID()
    viewModel.loadChat(threadId: chatId)
    
    return ChatView(
        chatId: chatId,
        title: viewModel.chatThreads.first?.title ?? "Чат с ассистентом",
        viewModel: viewModel
    )
} 