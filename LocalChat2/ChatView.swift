import SwiftUI
import Combine
import MultipeerConnectivity

// MARK: - ChatViewModel
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var messageText = ""
    @Published var isConnected = false
    
    private let mpcManager = MPCManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        setupDataHandling()
    }
    
    private func setupBindings() {
        mpcManager.$connectionState
            .map { $0 == .connected }
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
    }
    
    private func setupDataHandling() {
        mpcManager.onReceiveData = { [weak self] data, peer in
            self?.handleReceivedData(data, from: peer)
        }
    }
    
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            
            switch envelope.kind {
            case .chat:
                let message = try envelope.decode(as: ChatMessage.self)
                DispatchQueue.main.async {
                    self.messages.append(message)
                }
            case .presence, .gameMove, .gameSync:
                // Handle other message types if needed
                break
            }
        } catch {
            print("Failed to decode received data: \(error)")
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isConnected else { return }
        
        let message = ChatMessage(sender: mpcManager.displayName, text: messageText.trimmingCharacters(in: .whitespacesAndNewlines))
        
        do {
            let envelope = try Envelope(kind: .chat, payload: message)
            let data = try JSONEncoder().encode(envelope)
            
            mpcManager.send(data: data, reliably: true)
            
            DispatchQueue.main.async {
                self.messages.append(message)
                self.messageText = ""
            }
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    func clearMessages() {
        messages.removeAll()
    }
}

// MARK: - ChatView
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var mpcManager: MPCManager
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isConnected {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    ChatMessageView(message: message, isFromCurrentUser: message.sender == mpcManager.displayName)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Message Input
                    VStack(spacing: 0) {
                        Divider()
                        
                        HStack(spacing: 12) {
                            TextField("メッセージを入力...", text: $viewModel.messageText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    viewModel.sendMessage()
                                }
                            
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                        Color.gray : Color.blue
                                    )
                                    .cornerRadius(18)
                            }
                            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                } else {
                    // Not Connected State
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "message.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            Text("チャットを開始するには")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("まずルーム画面で友達と接続してください")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("チャット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isConnected && !viewModel.messages.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("クリア") {
                            viewModel.clearMessages()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - ChatMessageView
struct ChatMessageView: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    Text(message.sender)
                        .captionStyle()
                }
                
                Text(message.text)
                    .bodyStyle()
                    .messageBubbleStyle(isFromCurrentUser: isFromCurrentUser)
                
                Text(timeFormatter.string(from: message.timestamp))
                    .captionStyle()
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}
