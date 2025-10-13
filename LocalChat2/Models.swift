import Foundation

// MARK: - Envelope
struct Envelope: Codable {
    let kind: EnvelopeKind
    let data: Data
    
    enum EnvelopeKind: String, Codable, CaseIterable {
        case chat = "chat"
        case presence = "presence"
        case gameMove = "gameMove"
        case gameSync = "gameSync"
    }
    
    init<T: Codable>(kind: EnvelopeKind, payload: T) throws {
        self.kind = kind
        self.data = try JSONEncoder().encode(payload)
    }
    
    func decode<T: Codable>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - ChatMessage
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let sender: String
    let text: String
    let timestamp: Date
    
    init(sender: String, text: String) {
        self.id = UUID()
        self.sender = sender
        self.text = text
        self.timestamp = Date()
    }
}

// MARK: - Presence
struct Presence: Codable {
    let displayName: String
    let isHost: Bool
    let timestamp: Date
    
    init(displayName: String, isHost: Bool) {
        self.displayName = displayName
        self.isHost = isHost
        self.timestamp = Date()
    }
}

// MARK: - GameMove
struct GameMove: Codable {
    let game: GameType
    let payload: Data
    
    enum GameType: String, Codable, CaseIterable {
        case connect4 = "connect4"
        case reversi = "reversi"
    }
    
    init<T: Codable>(game: GameType, move: T) throws {
        self.game = game
        self.payload = try JSONEncoder().encode(move)
    }
    
    func decodeMove<T: Codable>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: payload)
    }
}

// MARK: - GameSync
struct GameSync: Codable {
    let game: GameMove.GameType
    let state: Data
    
    init<T: Codable>(game: GameMove.GameType, state: T) throws {
        self.game = game
        self.state = try JSONEncoder().encode(state)
    }
    
    func decodeState<T: Codable>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: state)
    }
}

// MARK: - Connect4 Models
struct Connect4Move: Codable {
    let column: Int
    let player: Connect4Player
}

enum Connect4Player: String, Codable, CaseIterable {
    case player1 = "player1"
    case player2 = "player2"
    
    var displayName: String {
        switch self {
        case .player1:
            return "プレイヤー1"
        case .player2:
            return "プレイヤー2"
        }
    }
    
    var color: String {
        switch self {
        case .player1:
            return "red"
        case .player2:
            return "yellow"
        }
    }
}

struct Connect4State: Codable {
    var board: [[Connect4Player?]]
    var currentPlayer: Connect4Player
    var winner: Connect4Player?
    var isGameOver: Bool
    var moveCount: Int
    
    init() {
        self.board = Array(repeating: Array(repeating: nil, count: 7), count: 6)
        self.currentPlayer = .player1
        self.winner = nil
        self.isGameOver = false
        self.moveCount = 0
    }
    
    mutating func makeMove(column: Int) -> Bool {
        guard !isGameOver && column >= 0 && column < 7 else { return false }
        
        // Find the lowest empty row in the column
        for row in stride(from: 5, through: 0, by: -1) {
            if board[row][column] == nil {
                board[row][column] = currentPlayer
                moveCount += 1
                
                // Check for win
                if checkWin(row: row, column: column) {
                    winner = currentPlayer
                    isGameOver = true
                } else if moveCount >= 42 {
                    // Board is full, it's a draw
                    isGameOver = true
                } else {
                    // Switch players
                    currentPlayer = currentPlayer == .player1 ? .player2 : .player1
                }
                
                return true
            }
        }
        
        return false // Column is full
    }
    
    private func checkWin(row: Int, column: Int) -> Bool {
        let player = board[row][column]!
        
        // Check horizontal
        if checkDirection(row: row, column: column, deltaRow: 0, deltaColumn: 1, player: player) >= 4 ||
           checkDirection(row: row, column: column, deltaRow: 0, deltaColumn: -1, player: player) >= 4 {
            return true
        }
        
        // Check vertical
        if checkDirection(row: row, column: column, deltaRow: 1, deltaColumn: 0, player: player) >= 4 ||
           checkDirection(row: row, column: column, deltaRow: -1, deltaColumn: 0, player: player) >= 4 {
            return true
        }
        
        // Check diagonal (top-left to bottom-right)
        if checkDirection(row: row, column: column, deltaRow: 1, deltaColumn: 1, player: player) >= 4 ||
           checkDirection(row: row, column: column, deltaRow: -1, deltaColumn: -1, player: player) >= 4 {
            return true
        }
        
        // Check diagonal (top-right to bottom-left)
        if checkDirection(row: row, column: column, deltaRow: 1, deltaColumn: -1, player: player) >= 4 ||
           checkDirection(row: row, column: column, deltaRow: -1, deltaColumn: 1, player: player) >= 4 {
            return true
        }
        
        return false
    }
    
    private func checkDirection(row: Int, column: Int, deltaRow: Int, deltaColumn: Int, player: Connect4Player) -> Int {
        var count = 1
        var currentRow = row + deltaRow
        var currentColumn = column + deltaColumn
        
        while currentRow >= 0 && currentRow < 6 && currentColumn >= 0 && currentColumn < 7 &&
              board[currentRow][currentColumn] == player {
            count += 1
            currentRow += deltaRow
            currentColumn += deltaColumn
        }
        
        return count
    }
}

// MARK: - Reversi Models
struct ReversiMove: Codable {
    let row: Int
    let column: Int
    let isPass: Bool
    let player: ReversiPlayer
}

enum ReversiPlayer: String, Codable, CaseIterable {
    case black = "black"
    case white = "white"
    
    var displayName: String {
        switch self {
        case .black:
            return "黒"
        case .white:
            return "白"
        }
    }
    
    var color: String {
        switch self {
        case .black:
            return "black"
        case .white:
            return "white"
        }
    }
}

struct ReversiState: Codable {
    var board: [[ReversiPlayer?]]
    var currentPlayer: ReversiPlayer
    var winner: ReversiPlayer?
    var isGameOver: Bool
    var blackCount: Int
    var whiteCount: Int
    var consecutivePasses: Int
    
    init() {
        self.board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        self.currentPlayer = .black
        self.winner = nil
        self.isGameOver = false
        self.blackCount = 2
        self.whiteCount = 2
        self.consecutivePasses = 0
        
        // Initial setup
        board[3][3] = .white
        board[3][4] = .black
        board[4][3] = .black
        board[4][4] = .white
    }
    
    mutating func makeMove(row: Int, column: Int) -> Bool {
        guard !isGameOver && row >= 0 && row < 8 && column >= 0 && column < 8 else { return false }
        guard board[row][column] == nil else { return false }
        
        let flippedPieces = getFlippedPieces(row: row, column: column, player: currentPlayer)
        guard !flippedPieces.isEmpty else { return false }
        
        // Place the piece
        board[row][column] = currentPlayer
        
        // Flip pieces
        for (flipRow, flipColumn) in flippedPieces {
            board[flipRow][flipColumn] = currentPlayer
        }
        
        // Update counts
        updateCounts()
        
        // Switch players
        currentPlayer = currentPlayer == .black ? .white : .black
        consecutivePasses = 0
        
        // Check if game is over
        if !hasValidMoves(player: currentPlayer) {
            consecutivePasses += 1
            if consecutivePasses >= 2 {
                isGameOver = true
                determineWinner()
            } else {
                currentPlayer = currentPlayer == .black ? .white : .black
            }
        }
        
        return true
    }
    
    mutating func pass() -> Bool {
        guard !isGameOver && !hasValidMoves(player: currentPlayer) else { return false }
        
        consecutivePasses += 1
        currentPlayer = currentPlayer == .black ? .white : .black
        
        if consecutivePasses >= 2 {
            isGameOver = true
            determineWinner()
        }
        
        return true
    }
    
    private func getFlippedPieces(row: Int, column: Int, player: ReversiPlayer) -> [(Int, Int)] {
        var flippedPieces: [(Int, Int)] = []
        let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        
        for (deltaRow, deltaColumn) in directions {
            var currentRow = row + deltaRow
            var currentColumn = column + deltaColumn
            var piecesToFlip: [(Int, Int)] = []
            
            while currentRow >= 0 && currentRow < 8 && currentColumn >= 0 && currentColumn < 8 {
                if let piece = board[currentRow][currentColumn] {
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
    
    private func hasValidMoves(player: ReversiPlayer) -> Bool {
        for row in 0..<8 {
            for column in 0..<8 {
                if board[row][column] == nil && !getFlippedPieces(row: row, column: column, player: player).isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    private mutating func updateCounts() {
        blackCount = 0
        whiteCount = 0
        
        for row in 0..<8 {
            for column in 0..<8 {
                if let piece = board[row][column] {
                    if piece == .black {
                        blackCount += 1
                    } else {
                        whiteCount += 1
                    }
                }
            }
        }
    }
    
    private mutating func determineWinner() {
        if blackCount > whiteCount {
            winner = .black
        } else if whiteCount > blackCount {
            winner = .white
        } else {
            winner = nil // Draw
        }
    }
}
