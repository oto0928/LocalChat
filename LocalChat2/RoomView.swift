import SwiftUI
import MultipeerConnectivity

// MARK: - Main TabView
struct MainTabView: View {
    @StateObject private var mpcManager = MPCManager.shared
    
    var body: some View {
        TabView {
            RoomView()
                .tabItem {
                    Image(systemName: "wifi")
                    Text("ルーム")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "message")
                    Text("チャット")
                }
            
            GamesView()
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("ゲーム")
                }
        }
        .customTabBarStyle()
        .environmentObject(mpcManager)
    }
}

// MARK: - RoomView
struct RoomView: View {
    @EnvironmentObject var mpcManager: MPCManager
    @State private var showingNameAlert = false
    @State private var tempDisplayName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "wifi")
                        .iconStyle(size: 60, color: AppColors.primaryBlue)
                    
                    Text("LocalChat")
                        .titleStyle()
                    
                    Text("近くの友達とチャット・ゲームを楽しもう")
                        .captionStyle()
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Connection Status
                VStack(spacing: 12) {
                    HStack {
                        StatusIndicator(status: mpcManager.connectionState, size: 12)
                        
                        Text(mpcManager.connectionState.description)
                            .subtitleStyle()
                        
                        Spacer()
                    }
                    
                    if !mpcManager.connectedPeers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("接続中のプレイヤー")
                                .captionStyle()
                            
                            ForEach(mpcManager.connectedPeers, id: \.self) { peer in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .iconStyle(size: 20, color: AppColors.successGreen)
                                    Text(peer.displayName)
                                        .bodyStyle()
                                    Spacer()
                                }
                            }
                        }
                        .cardStyle()
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 16) {
                    if mpcManager.connectionState == .disconnected {
                        // Host Button
                        Button(action: {
                            mpcManager.startHosting()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("ホストを開始")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        // Browse Button
                        Button(action: {
                            mpcManager.startBrowsing()
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("近くを検索")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        // Disconnect Button
                        Button(action: {
                            mpcManager.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("切断")
                            }
                        }
                        .buttonStyle(GameButtonStyle(color: AppColors.errorRed))
                    }
                }
                .padding(.horizontal)
                
                // Discovered Peers
                if mpcManager.isBrowsing && !mpcManager.discoveredPeers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("見つかったプレイヤー")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(mpcManager.discoveredPeers, id: \.self) { peer in
                            Button(action: {
                                mpcManager.invite(peer: peer)
                            }) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                    Text(peer.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Settings
                Button(action: {
                    tempDisplayName = mpcManager.displayName
                    showingNameAlert = true
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("設定")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("ルーム")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("表示名を変更", isPresented: $showingNameAlert) {
            TextField("表示名", text: $tempDisplayName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                mpcManager.displayName = tempDisplayName
            }
        } message: {
            Text("他のプレイヤーに表示される名前を入力してください")
        }
    }
}

// MARK: - GamesView
struct GamesView: View {
    @EnvironmentObject var mpcManager: MPCManager
    @State private var selectedGame: GameMove.GameType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .iconStyle(size: 60, color: AppColors.accentPurple)
                    
                    Text("ゲーム")
                        .titleStyle()
                    
                    Text("友達と一緒にゲームを楽しもう")
                        .captionStyle()
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Game Selection
                VStack(spacing: 16) {
                    if mpcManager.connectionState == .connected {
                        Text("ゲームを選択してください")
                            .subtitleStyle()
                        
                        // Connect4 Button
                        Button(action: {
                            selectedGame = .connect4
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "circle.grid.3x3.fill")
                                    .iconStyle(size: 40, color: AppColors.errorRed)
                                
                                Text("四目並べ")
                                    .subtitleStyle()
                                
                                Text("6×7の盤面で4つ揃えて勝利")
                                    .captionStyle()
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                        }
                        
                        // Reversi Button
                        Button(action: {
                            selectedGame = .reversi
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "circle.grid.2x2.fill")
                                    .iconStyle(size: 40, color: .black)
                                
                                Text("オセロ")
                                    .subtitleStyle()
                                
                                Text("8×8の盤面で石を挟んで反転")
                                    .captionStyle()
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .iconStyle(size: 40, color: .gray)
                            
                            Text("ゲームをプレイするには")
                                .subtitleStyle()
                            
                            Text("まずルーム画面で友達と接続してください")
                                .captionStyle()
                                .multilineTextAlignment(.center)
                        }
                        .cardStyle()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("ゲーム")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedGame) { gameType in
            if gameType == .connect4 {
                Connect4GameView()
            } else if gameType == .reversi {
                ReversiGameView()
            }
        }
    }
}

// MARK: - Extensions
extension GameMove.GameType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Preview
struct RoomView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
