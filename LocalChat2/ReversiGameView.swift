import SwiftUI
import Combine
import MultipeerConnectivity

// MARK: - ReversiViewModel
class ReversiViewModel: ObservableObject {
    @Published var gameState = ReversiState()
    @Published var isHost = false
    @Published var currentPlayer: ReversiPlayer = .black
    @Published var gameStatus: GameStatus = .waiting
    @Published var winner: ReversiPlayer?
    @Published var isMyTurn = false
    @Published var validMoves: [(Int, Int)] = []
    
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
        currentPlayer = isHost ? .black : .white
    }
    
    private func startGame() {
        gameStatus = .playing
        isMyTurn = isHost
        updateValidMoves()
        syncGameState()
    }
    
    
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            
            switch envelope.kind {
            case .gameMove:
                let gameMove = try envelope.decode(as: GameMove.self)
                if gameMove.game == .reversi {
                    let move = try gameMove.decodeMove(as: ReversiMove.self)
                    handleReceivedMove(move)
                }
            case .gameSync:
                let gameSync = try envelope.decode(as: GameSync.self)
                if gameSync.game == .reversi {
                    let state = try gameSync.decodeState(as: ReversiState.self)
                    handleReceivedState(state)
                }
            default:
                break
            }
        } catch {
            print("Failed to decode game data: \(error)")
        }
    }
    
    private func handleReceivedMove(_ move: ReversiMove) {
        DispatchQueue.main.async {
            if move.isPass {
                _ = self.gameState.pass()
            } else {
                _ = self.gameState.makeMove(row: move.row, column: move.column)
            }
            
            self.isMyTurn = self.gameState.currentPlayer == self.currentPlayer
            self.updateValidMoves()
            self.checkGameEnd()
        }
    }
    
    private func handleReceivedState(_ state: ReversiState) {
        DispatchQueue.main.async {
            self.gameState = state
            self.isMyTurn = self.gameState.currentPlayer == self.currentPlayer
            self.updateValidMoves()
            self.checkGameEnd()
        }
    }
    
    func makeMove(row: Int, column: Int) {
        guard isMyTurn && gameStatus == .playing else { return }
        guard validMoves.contains(where: { $0.0 == row && $0.1 == column }) else { return }
        guard gameState.makeMove(row: row, column: column) else { return }
        
        isMyTurn = false
        
        // Send move to other player
        let move = ReversiMove(row: row, column: column, isPass: false, player: currentPlayer)
        sendMove(move)
        
        updateValidMoves()
        checkGameEnd()
    }
    
    func passMove() {
        guard isMyTurn && gameStatus == .playing else { return }
        guard gameState.pass() else { return }
        
        isMyTurn = false
        
        // Send pass move to other player
        let move = ReversiMove(row: 0, column: 0, isPass: true, player: currentPlayer)
        sendMove(move)
        
        updateValidMoves()
        checkGameEnd()
    }
    
    private func sendMove(_ move: ReversiMove) {
        do {
            let gameMove = try GameMove(game: .reversi, move: move)
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
            let gameSync = try GameSync(game: .reversi, state: gameState)
            let envelope = try Envelope(kind: .gameSync, payload: gameSync)
            let data = try JSONEncoder().encode(envelope)
            
            mpcManager.send(data: data, reliably: true)
        } catch {
            print("Failed to sync game state: \(error)")
        }
    }
    
    private func updateValidMoves() {
        validMoves = []
        
        for row in 0..<8 {
            for column in 0..<8 {
                if gameState.board[row][column] == nil {
                    let flippedPieces = getFlippedPieces(row: row, column: column, player: gameState.currentPlayer)
                    if !flippedPieces.isEmpty {
                        validMoves.append((row, column))
                    }
                }
            }
        }
    }
    
    private func getFlippedPieces(row: Int, column: Int, player: ReversiPlayer) -> [(Int, Int)] {
        var flippedPieces: [(Int, Int)] = []
        let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        
        for (deltaRow, deltaColumn) in directions {
            var currentRow = row + deltaRow
            var currentColumn = column + deltaColumn
            var piecesToFlip: [(Int, Int)] = []
            
            while currentRow >= 0 && currentRow < 8 && currentColumn >= 0 && currentColumn < 8 {
                if let piece = gameState.board[currentRow][currentColumn] {
                    if piece == player {
                        flippedPieces.append(contentsOf: piecesToFlip)
                        break
                    } else {
                        piecesToFlip.append((currentRow, currentColumn))
                    }
                } else {
                    break
                }
                currentRow += deltaRow
                currentColumn += deltaColumn
            }
        }
        
        return flippedPieces
    }
    
    private func checkGameEnd() {
        if gameState.isGameOver {
            gameStatus = .finished
            winner = gameState.winner
        }
    }
    
    func resetGame() {
        gameState = ReversiState()
        gameStatus = .playing
        winner = nil
        isMyTurn = isHost
        updateValidMoves()
        syncGameState()
    }
    
    private func clearGame() {
        gameState = ReversiState()
        gameStatus = .waiting
        winner = nil
        isMyTurn = false
        validMoves = []
    }
}

// MARK: - ReversiGameView
struct ReversiGameView: View {
    @StateObject private var viewModel = ReversiViewModel()
    @Environment(\.dismiss) private var dismiss
    
    private let columns = Array(0..<8)
    private let rows = Array(0..<8)
    
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
                                .fill(viewModel.currentPlayer == .black ? Color.black : Color.white)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
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
                    
                    // Score
                    HStack(spacing: 20) {
                        HStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 16, height: 16)
                            Text("\(viewModel.gameState.blackCount)")
                                .font(.headline)
                        }
                        
                        Text("vs")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            Text("\(viewModel.gameState.whiteCount)")
                                .font(.headline)
                        }
                    }
                    
                    if let winner = viewModel.winner {
                        Text("🎉 \(winner.displayName)の勝利！")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(winner == .black ? .black : .gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Game Board
                VStack(spacing: 2) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(columns, id: \.self) { column in
                                Button(action: {
                                    viewModel.makeMove(row: row, column: column)
                                }) {
                                    ZStack {
                                        Rectangle()
                                            .fill(cellColor(row: row, column: column))
                                            .frame(width: 35, height: 35)
                                            .overlay(
                                                Rectangle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        if let player = viewModel.gameState.board[row][column] {
                                            Circle()
                                                .fill(player == .black ? Color.black : Color.white)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.gray, lineWidth: 1)
                                                )
                                        } else if viewModel.validMoves.contains(where: { $0.0 == row && $0.1 == column }) {
                                            Circle()
                                                .fill(Color.green.opacity(0.3))
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                }
                                .disabled(!viewModel.isMyTurn || viewModel.gameStatus != .playing)
                            }
                        }
                    }
                }
                .gameBoardStyle(backgroundColor: .green)
                
                // Pass Button
                if viewModel.gameStatus == .playing && viewModel.isMyTurn && viewModel.validMoves.isEmpty {
                    Button(action: {
                        viewModel.passMove()
                    }) {
                        Text("パス")
                    }
                    .buttonStyle(GameButtonStyle(color: AppColors.warningOrange))
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
            .navigationTitle("オセロ")
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
        return Color.green.opacity(0.3)
    }
}
