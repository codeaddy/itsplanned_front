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
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                
                Image(systemName: "arrow.left")
                    .foregroundColor(.clear)
                    .font(.system(size: 20))
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.currentMessages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                
                                ProgressView()
                                    .padding(.vertical, 10)
                                
                                Spacer()
                            }
                        }
                        
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
                    withAnimation {
                        scrollView.scrollTo("bottomID", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    withAnimation {
                        scrollView.scrollTo("bottomID", anchor: .bottom)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollView.scrollTo("bottomID", anchor: .bottom)
                        }
                    }
                }
            }
            
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
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
                            .disabled(viewModel.isLoading)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            sendMessage()
                        }
                    }) {
                        Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.blue))
                    }
                    .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    .opacity(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading ? 0.4 : 1.0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadChat(threadId: chatId)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Ошибка"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
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
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(ChatBubbleShape(isFromUser: true))
                    .overlay(
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .offset(y: 18),
                        alignment: .bottomLeading
                    )
                    .padding(.bottom, 15)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Text("👨‍💻")
                        .font(.system(size: 18))
                }
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(ChatBubbleShape(isFromUser: false))
                    .overlay(
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .offset(y: 18),
                        alignment: .bottomTrailing
                    )
                    .padding(.bottom, 15)
                
                Spacer()
            }
        }
    }
}

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