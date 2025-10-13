import SwiftUI
import Combine
import MultipeerConnectivity

// MARK: - Connect4ViewModel
class Connect4ViewModel: ObservableObject {
    @Published var gameState = Connect4State()
    @Published var isHost = false
    @Published var currentPlayer: Connect4Player = .player1
    @Published var gameStatus: GameStatus = .waiting
    @Published var winner: Connect4Player?
    @Published var isMyTurn = false
    
    private let mpcManager = MPCManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum GameStatus {
        case waiting
        case playing
        case finished
        
        var description: String {
            switch self {
            case .waiting:
                return "ゲーム開始待ち"
            case .playing:
                return "プレイ中"
            case .finished:
                return "ゲーム終了"
            }
        }
    }
    
    init() {
        setupBindings()
        setupDataHandling()
        determineHost()
    }
    
    private func setupBindings() {
        mpcManager.$connectionState
            .sink { [weak self] state in
                if state == .connected {
                    self?.startGame()
                } else {
                    self?.clearGame()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupDataHandling() {
        mpcManager.onReceiveData = { [weak self] data, peer in
            self?.handleReceivedData(data, from: peer)
        }
    }
    
    private func determineHost() {
        // Simple host determination based on display name
        isHost = mpcManager.displayName < mpcManager.connectedPeers.first?.displayName ?? ""
        currentPlayer = isHost ? .player1 : .player2
    }
    
    private func startGame() {
        gameStatus = .playing
        isMyTurn = isHost
        syncGameState()
    }
    
    
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            
            switch envelope.kind {
            case .gameMove:
                let gameMove = try envelope.decode(as: GameMove.self)
                if gameMove.game == .connect4 {
                    let move = try gameMove.decodeMove(as: Connect4Move.self)
                    handleReceivedMove(move)
                }
            case .gameSync:
                let gameSync = try envelope.decode(as: GameSync.self)
                if gameSync.game == .connect4 {
                    let state = try gameSync.decodeState(as: Connect4State.self)
                    handleReceivedState(state)
                }
            default:
                break
            }
        } catch {
            print("Failed to decode game data: \(error)")
        }
    }
    
    private func handleReceivedMove(_ move: Connect4Move) {
        DispatchQueue.main.async {
            if self.gameState.makeMove(column: move.column) {
                self.isMyTurn = true
                self.checkGameEnd()
            }
        }
    }
    
    private func handleReceivedState(_ state: Connect4State) {
        DispatchQueue.main.async {
            self.gameState = state
            self.isMyTurn = self.gameState.currentPlayer == self.currentPlayer
            self.checkGameEnd()
        }
    }
    
    func makeMove(column: Int) {
        guard isMyTurn && gameStatus == .playing else { return }
        guard gameState.makeMove(column: column) else { return }
        
        isMyTurn = false
        
        // Send move to other player
        let move = Connect4Move(column: column, player: currentPlayer)
        sendMove(move)
        
        checkGameEnd()
    }
    
    private func sendMove(_ move: Connect4Move) {
        do {
            let gameMove = try GameMove(game: .connect4, move: move)
            let envelope = try Envelope(kind: .gameMove, payload: gameMove)
            let data = try JSONEncoder().encode(envelope)
            
            mpcManager.send(data: data, reliably: true)
        } catch {
            print("Failed to send move: \(error)")
        }
    }
    
    private func syncGameState() {
        guard isHost else { return }
        
        do {
            let gameSync = try GameSync(game: .connect4, state: gameState)
            let envelope = try Envelope(kind: .gameSync, payload: gameSync)
            let data = try JSONEncoder().encode(envelope)
            
            mpcManager.send(data: data, reliably: true)
        } catch {
            print("Failed to sync game state: \(error)")
        }
    }
    
    private func checkGameEnd() {
        if gameState.isGameOver {
            gameStatus = .finished
            winner = gameState.winner
        }
    }
    
    func resetGame() {
        gameState = Connect4State()
        gameStatus = .playing
        winner = nil
        isMyTurn = isHost
        syncGameState()
    }
    
    private func clearGame() {
        gameState = Connect4State()
        gameStatus = .waiting
        winner = nil
        isMyTurn = false
    }
}

// MARK: - Connect4GameView
struct Connect4GameView: View {
    @StateObject private var viewModel = Connect4ViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private let columns = Array(0..<7)
    private let rows = Array(0..<6)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Game Status
                VStack(spacing: 8) {
                    Text(viewModel.gameStatus.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.gameStatus == .playing {
                        HStack {
                            Circle()
                                .fill(viewModel.currentPlayer == .player1 ? Color.red : Color.yellow)
                                .frame(width: 20, height: 20)
                            
                            Text("現在のプレイヤー: \(viewModel.currentPlayer.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.isMyTurn {
                            Text("あなたのターンです")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        } else {
                            Text("相手のターンです")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let winner = viewModel.winner {
                        Text("🎉 \(winner.displayName)の勝利！")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(winner == .player1 ? .red : .yellow)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Game Board
                VStack(spacing: 4) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(columns, id: \.self) { column in
                                Circle()
                                    .fill(cellColor(row: row, column: column))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .gameBoardStyle(backgroundColor: .blue)
                
                // Column Buttons
                if viewModel.gameStatus == .playing && viewModel.isMyTurn {
                    HStack(spacing: 4) {
                        ForEach(columns, id: \.self) { column in
                            Button(action: {
                                viewModel.makeMove(column: column)
                            }) {
                                Text("\(column + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 30)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .disabled(!canMakeMove(column: column))
                        }
                    }
                }
                
                // Reset Button
                if viewModel.gameStatus == .finished {
                    Button(action: {
                        viewModel.resetGame()
                    }) {
                        Text("新しいゲーム")
                    }
                    .buttonStyle(GameButtonStyle(color: AppColors.successGreen))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("四目並べ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func cellColor(row: Int, column: Int) -> Color {
        guard let player = viewModel.gameState.board[row][column] else {
            return Color.white
        }
        
        return player == .player1 ? Color.red : Color.yellow
    }
    
    private func canMakeMove(column: Int) -> Bool {
        return viewModel.gameState.board[0][column] == nil
    }
}
