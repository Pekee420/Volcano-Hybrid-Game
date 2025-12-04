//
//  Models.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import Foundation
import CoreGraphics

struct Player: Identifiable, Codable, Equatable {
    let id = UUID()
    var name: String
    var points: Int = 0
    var isEliminated: Bool = false
    var completedCycles: Int = 0
    var failedCycles: Int = 0
    var isAI: Bool = false // For Snoop Dogg mode
    var skippedLastTurn: Bool = false // True if player didn't press button
    var cyclePenalty: TimeInterval = 0 // Seconds to subtract from next cycle
    var consecutiveFailures: Int = 0 // Track failures in a row for elimination

    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Persistent Leaderboard

struct HighScore: Identifiable, Codable {
    let id: UUID
    let playerName: String
    let score: Int
    let rounds: Int
    let date: Date
    
    init(playerName: String, score: Int, rounds: Int) {
        self.id = UUID()
        self.playerName = playerName
        self.score = score
        self.rounds = rounds
        self.date = Date()
    }
}

class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()
    
    @Published var highScores: [HighScore] = []
    
    private let userDefaultsKey = "VolcanoGameHighScores"
    
    private init() {
        loadHighScores()
    }
    
    func addScore(playerName: String, score: Int, rounds: Int) {
        // Check if player already has a score
        if let existingIndex = highScores.firstIndex(where: { $0.playerName == playerName }) {
            // Only update if new score is higher
            if score > highScores[existingIndex].score {
                highScores[existingIndex] = HighScore(playerName: playerName, score: score, rounds: rounds)
            }
        } else {
            // New player, add their score
            let newScore = HighScore(playerName: playerName, score: score, rounds: rounds)
            highScores.append(newScore)
        }
        
        // Sort by score descending
        highScores.sort { $0.score > $1.score }
        
        // Keep top 50 players
        if highScores.count > 50 {
            highScores = Array(highScores.prefix(50))
        }
        saveHighScores()
    }
    
    func saveHighScores() {
        if let encoded = try? JSONEncoder().encode(highScores) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func loadHighScores() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([HighScore].self, from: data) {
            // Deduplicate on load - keep only highest score per player
            var bestScores: [String: HighScore] = [:]
            for score in decoded {
                if let existing = bestScores[score.playerName] {
                    if score.score > existing.score {
                        bestScores[score.playerName] = score
                    }
                } else {
                    bestScores[score.playerName] = score
                }
            }
            highScores = Array(bestScores.values).sorted { $0.score > $1.score }
        }
    }
    
    func clearHighScores() {
        highScores = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

struct GameSettings: Codable {
    var initialCycleDuration: TimeInterval = 5.0 // seconds
    var cycleIncrement: TimeInterval = 2.0 // seconds added each cycle
    var pauseBetweenCycles: TimeInterval = 3.0 // seconds
    var preparationTime: TimeInterval = 5.0 // seconds to prepare before cycle starts
    var penaltyPoints: Int = 10 // points subtracted for early release
    var completionBonus: Int = 20 // bonus points for completing on first try
    var hardcoreMode: Bool = false // eliminate players who fail cycles
    var temperature: Int = 200 // temperature in Celsius (150-220 range)
    var totalRounds: Int = 3 // number of rounds (1 round = all players play once)
    var singlePlayerMode: Bool = false // Play against Snoop Dogg AI
}

enum GamePhase {
    case setup
    case waitingForTemp // waiting for volcano to reach target temp
    case preparation // countdown before cycle starts
    case active // player holding button
    case completed // cycle finished successfully
    case failed // player released too early
    case eliminated // showing who got eliminated
    case paused // between cycles
    case finished // game over
}

class GameState: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentPlayerIndex: Int = 0
    @Published var currentCycle: Int = 1 // Total cycles played
    @Published var currentRound: Int = 1 // Current round (1 round = all players played once)
    @Published var turnsInCurrentRound: Int = 0 // How many players have played this round
    @Published var gamePhase: GamePhase = .setup {
        didSet {
            handlePhaseChange(from: oldValue, to: gamePhase)
        }
    }
    @Published var timeRemaining: TimeInterval = 0
    @Published var cycleDuration: TimeInterval = 5.0
    @Published var isButtonPressed: Bool = false
    @Published var buttonPressStartTime: Date?
    @Published var settings: GameSettings = GameSettings()
    @Published var eliminatedPlayerName: String? = nil // Track who just got eliminated
    @Published var lastDrawTime: TimeInterval = 0 // How long player held on last cycle
    @Published var lastPointsEarned: Int = 0 // Points earned on last cycle
    
    private var idleTimer: Timer?
    private let idleTimeout: TimeInterval = 30.0 // Turn off heater after 30 sec idle in menu
    
    private func handlePhaseChange(from oldPhase: GamePhase, to newPhase: GamePhase) {
        // Cancel any existing idle timer
        idleTimer?.invalidate()
        idleTimer = nil
        
        switch newPhase {
        case .setup, .finished:
            // Start idle timer - turn off heater after 30 sec
            print("⏱️ Starting idle timer - heater will turn off in 30 sec if no action")
            idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
                print("💤 Idle timeout - turning heater OFF")
                BluetoothManager.shared.stopHeater()
            }
            
        case .waitingForTemp, .preparation, .active, .completed, .failed, .paused, .eliminated:
            // Game is running - heater managed by WaitingForTempView only
            break
        }
    }

    var currentPlayer: Player? {
        guard !players.isEmpty, currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    var upcomingPlayer: Player? {
        guard !activePlayers.isEmpty, activePlayers.count > 1 else { return nil }

        var nextIndex = currentPlayerIndex
        repeat {
            nextIndex = (nextIndex + 1) % players.count
        } while players[nextIndex].isEliminated && activePlayers.count > 1

        return players[nextIndex]
    }

    var activePlayers: [Player] {
        players.filter { !$0.isEliminated }
    }

    var rankedPlayers: [Player] {
        players.sorted { $0.points > $1.points }
    }

    func addPlayer(name: String) {
        print("🎮 GameState.addPlayer called with name: \(name)")
        let player = Player(name: name)
        players.append(player)
        print("🎮 Player added to gameState, total players: \(players.count)")
    }

    func removePlayer(at index: Int) {
        players.remove(at: index)
    }

    func nextPlayer() {
        guard !activePlayers.isEmpty else { return }

        // Increment turns in current round
        turnsInCurrentRound += 1
        
        // Check if round is complete (all active players have played)
        if turnsInCurrentRound >= activePlayers.count {
            // Round complete!
            currentRound += 1
            turnsInCurrentRound = 0
            print("🔄 Round \(currentRound - 1) complete! Starting round \(currentRound)")
            
            // Check if all rounds are done
            if currentRound > settings.totalRounds {
                print("🏁 All \(settings.totalRounds) rounds complete! Game finished!")
                saveGameToLeaderboard() // Save human players only
                gamePhase = .finished
                return
            }
        }

        // Move to next player (skip eliminated only - AI is handled in completeCycle)
        repeat {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        } while players[currentPlayerIndex].isEliminated && activePlayers.count > 1

        if activePlayers.count <= 1 {
            saveGameToLeaderboard() // Save human players only
            gamePhase = .finished
        }
    }

    func startNewCycle() {
        currentCycle += 1
        
        // Calculate base cycle duration based on game mode
        if settings.hardcoreMode {
            // Hardcore: add time after EACH run
            cycleDuration = settings.initialCycleDuration + TimeInterval(currentCycle - 1) * settings.cycleIncrement
        } else {
            // Normal: add time only after each ROUND (not each turn)
            cycleDuration = settings.initialCycleDuration + TimeInterval(currentRound - 1) * settings.cycleIncrement
        }
        
        // Apply player-specific penalty if they skipped their last turn (-2 seconds)
        if let player = currentPlayer, player.skippedLastTurn {
            cycleDuration = max(3, cycleDuration - 2) // Minimum 3 seconds
            print("⚠️ \(player.name) skipped last turn - cycle reduced to \(Int(cycleDuration))s")
        }
        
        // Calculate prep time - increases by 1/4 of cycle increment each round
        let prepTimeIncrease = (settings.cycleIncrement / 4.0) * TimeInterval(currentRound - 1)
        let currentPrepTime = settings.preparationTime + prepTimeIncrease
        
        gamePhase = .preparation
        timeRemaining = currentPrepTime
        print("⏳ Prep time: \(String(format: "%.1f", currentPrepTime))s (base \(Int(settings.preparationTime))s + \(String(format: "%.1f", prepTimeIncrease))s)")
        // IMPORTANT: Reset button state for new cycle
        isButtonPressed = false
        buttonPressStartTime = nil
    }

    func startCycle() {
        gamePhase = .active
        timeRemaining = cycleDuration
        
        // Double-check: is spacebar ACTUALLY pressed right now?
        let spacebarActuallyPressed = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(49))
        
        // Only consider button pressed if BOTH our state says so AND spacebar is physically held
        if isButtonPressed && spacebarActuallyPressed {
            buttonPressStartTime = Date()
            // START THE PUMP - player is actually holding spacebar!
            BluetoothManager.shared.startAirPump()
            print("⏰ Active phase started - player was ready, PUMP ON!")
        } else {
            // Reset state if spacebar not actually pressed
            isButtonPressed = false
            buttonPressStartTime = nil
            print("⏰ Active phase started - player NOT ready (spacebar not held)")
        }

        // Start fan for cooling during the cycle
        BluetoothManager.shared.startFan()

        SoundManager.shared.playCountdownSound()
    }

    func completeCycle(success: Bool, drawTime: TimeInterval = 0) {
        guard var player = currentPlayer else { return }

        // Stop the air pump and fan when cycle ends
        BluetoothManager.shared.stopAirPump()
        BluetoothManager.shared.stopFan()
        
        // Store draw time for display
        lastDrawTime = drawTime

        // Calculate points based on time held and completion
        // Points are divided by total rounds for even distribution
        var pointsEarned = 0

        if success {
            // 3 points per second held
            pointsEarned = Int(drawTime * 3)

            // +7 bonus for completing the full cycle
            pointsEarned += 7

            // +10 additional bonus if cycle was longer than 15 seconds
            if cycleDuration > 15 {
                pointsEarned += 10
            }

            player.completedCycles += 1
            gamePhase = .completed
            lastPointsEarned = pointsEarned
            SoundManager.shared.playSuccessSound(cycleDuration: cycleDuration)
            print("✅ Cycle complete! \(Int(drawTime))s held, +7 completion, \(cycleDuration > 15 ? "+10 long cycle" : "") = \(pointsEarned) points")
        } else {
            if drawTime > 0 {
                // Player held button but released early - points for time held only
                pointsEarned = Int(drawTime * 3)
                player.failedCycles += 1
                player.consecutiveFailures += 1
                player.skippedLastTurn = false // They pressed, just released early
                gamePhase = .failed
                lastPointsEarned = pointsEarned
                SoundManager.shared.playFailureSound(drawTime: drawTime)
                print("❌ Early release! \(Int(drawTime))s held = \(pointsEarned) points (streak: \(player.consecutiveFailures))")
            } else {
                // Player never pressed button - 0 points, next cycle is 2s shorter
                pointsEarned = 0
                player.failedCycles += 1
                player.consecutiveFailures += 1
                player.skippedLastTurn = true // Mark as skipped for next cycle penalty
                gamePhase = .failed
                lastPointsEarned = 0
                SoundManager.shared.playFailureSound(drawTime: 0)
                print("❌ No press = 0 points, next cycle -2s (streak: \(player.consecutiveFailures))")
            }

            // Eliminate in hardcore mode OR after 3 consecutive failures in normal mode
            var wasEliminated = false
            if settings.hardcoreMode {
                player.isEliminated = true
                wasEliminated = true
                eliminatedPlayerName = player.name
                SoundManager.shared.playEliminationSound()
                print("💀 \(player.name) eliminated (hardcore mode)")
            } else if player.consecutiveFailures >= 3 {
                player.isEliminated = true
                wasEliminated = true
                eliminatedPlayerName = player.name
                SoundManager.shared.playEliminationSound()
                print("💀 \(player.name) eliminated (3 failures in a row)")
            }
            
            // Show elimination screen if player was eliminated
            if wasEliminated {
                gamePhase = .eliminated
            }
        }

        // Clear failure streak and skip flag on success
        if success {
            player.skippedLastTurn = false
            player.consecutiveFailures = 0
        }

        player.points += pointsEarned

        // Update player in array
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index] = player
        }

        print("📊 Player \(player.name): \(success ? "SUCCESS" : "FAILED") - Held: \(String(format: "%.1f", drawTime))s - Points: +\(pointsEarned) (Total: \(player.points))")

        // Schedule next phase - longer delay if elimination shown
        let delay = gamePhase == .eliminated ? 4.0 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            eliminatedPlayerName = nil // Clear elimination display
            
            // Check if game is over (only 1 or 0 active players left)
            if activePlayers.count <= 1 {
                saveGameToLeaderboard()
                gamePhase = .finished
                return
            }
            
            // Move to next non-eliminated, non-AI player
            nextPlayer()
            
            // Check if next player is Snoop Dogg AI
            if let current = currentPlayer, current.isAI {
                // Snoop's turn - simulate his score based on your performance
                simulateSnoopTurn(yourScore: pointsEarned, yourDrawTime: drawTime, success: success)
            } else {
                // Start next cycle for human player
                startNewCycle()
            }
        }
    }
    
    // MARK: - Snoop Dogg AI
    
    func simulateSnoopTurn(yourScore: Int, yourDrawTime: TimeInterval, success: Bool) {
        guard let snoopIndex = players.firstIndex(where: { $0.isAI }) else { return }
        
        print("🐕 Snoop Dogg's turn! Cycle duration: \(cycleDuration)s")
        
        // Snoop performs independently - he's a pro smoker!
        // Base draw time is 60-100% of cycle duration
        let baseDrawTime = cycleDuration * Double.random(in: 0.6...1.0)
        
        // Snoop has 65% chance to complete the full cycle
        let snoopCompletes = Double.random(in: 0...1) < 0.65
        
        var snoopPoints = 0
        var snoopDrawTime: TimeInterval = 0
        
        if snoopCompletes {
            // Snoop completes the full cycle
            snoopDrawTime = cycleDuration
            // 3 points per second
            snoopPoints = Int(snoopDrawTime * 3)
            // +7 completion bonus
            snoopPoints += 7
            // +10 for long cycles
            if cycleDuration > 15 {
                snoopPoints += 10
            }
            players[snoopIndex].completedCycles += 1
            print("🐕 Snoop completed! Full \(String(format: "%.1f", snoopDrawTime))s = \(snoopPoints) points")
        } else {
            // Snoop releases early - gets 40-80% of cycle
            snoopDrawTime = cycleDuration * Double.random(in: 0.4...0.8)
            snoopPoints = Int(snoopDrawTime * 3)
            players[snoopIndex].failedCycles += 1
            print("🐕 Snoop released early at \(String(format: "%.1f", snoopDrawTime))s = \(snoopPoints) points")
        }
        
        players[snoopIndex].points += snoopPoints
        print("🐕 Snoop total: \(players[snoopIndex].points) points")
        
        // Move to next player (back to human)
        turnsInCurrentRound += 1
        
        // Check if round complete
        if turnsInCurrentRound >= activePlayers.count {
            currentRound += 1
            turnsInCurrentRound = 0
            
            // In normal mode, increase cycle time after each round
            if !settings.hardcoreMode {
                cycleDuration += settings.cycleIncrement
                print("📈 Round complete! New cycle duration: \(cycleDuration)s")
            }
            
            if currentRound > settings.totalRounds {
                // Save scores to leaderboard
                saveGameToLeaderboard()
                gamePhase = .finished
                return
            }
        }
        
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        
        // Skip back to human player
        while players[currentPlayerIndex].isAI && players.count > 1 {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        }
        
        // Continue game
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            startNewCycle()
        }
    }
    
    func saveGameToLeaderboard() {
        for player in players where !player.isAI {
            // Divide total score by rounds for even distribution across different game lengths
            let normalizedScore = player.points / max(1, settings.totalRounds)
            LeaderboardManager.shared.addScore(
                playerName: player.name,
                score: normalizedScore,
                rounds: settings.totalRounds
            )
        }
    }

    func startGame() {
        guard !players.isEmpty else { return }
        
        // Remove any existing AI players first
        players.removeAll { $0.isAI }
        
        // Count human players
        let humanPlayers = players.filter { !$0.isAI }
        
        // Add Snoop Dogg if single player mode OR only 1 human player (easter egg!)
        if settings.singlePlayerMode || humanPlayers.count == 1 {
            var snoop = Player(name: "🐕 Snoop Dogg")
            snoop.isAI = true
            players.append(snoop)
            print("🐕 Snoop Dogg has entered the game! 'Smoke weed every day!'")
        }
        
        currentPlayerIndex = 0
        // Make sure human player goes first
        while players[currentPlayerIndex].isAI && players.count > 1 {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        }
        
        currentCycle = 1
        currentRound = 1
        turnsInCurrentRound = 0
        cycleDuration = settings.initialCycleDuration
        
        // Check if we need to wait for temperature
        let currentTemp = BluetoothManager.shared.currentTemperature
        let targetTemp = settings.temperature
        let tempDiff = abs(currentTemp - targetTemp)
        
        if currentTemp == 0 || tempDiff > 5 {
            // Need to wait for temperature
            gamePhase = .waitingForTemp
            print("🌡️ Waiting for temperature... Current: \(currentTemp)°C, Target: \(targetTemp)°C")
        } else {
            // Temperature is good, start immediately
            gamePhase = .preparation
            timeRemaining = settings.preparationTime
            print("🎮 Game started! \(settings.totalRounds) rounds, \(players.count) players")
        }
    }
    
    func checkTemperatureAndStart() {
        let currentTemp = BluetoothManager.shared.currentTemperature
        let targetTemp = settings.temperature
        let tempDiff = abs(currentTemp - targetTemp)
        
        if tempDiff <= 5 && currentTemp > 0 {
            // Temperature reached! Pump air for 5 seconds then start
            print("🌡️ Temperature reached! Pumping air for 5 seconds...")
            BluetoothManager.shared.startAirPump()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [self] in
                BluetoothManager.shared.stopAirPump()
                gamePhase = .preparation
                timeRemaining = settings.preparationTime
                print("🎮 Game started! \(settings.totalRounds) rounds, \(players.count) players")
                SoundManager.shared.playGameStartSound()
            }
        }
    }
    
    func startSinglePlayerGame(playerName: String) {
        // Clear existing players
        players.removeAll()
        
        // Add human player
        addPlayer(name: playerName)
        
        // Enable single player mode
        settings.singlePlayerMode = true
        
        // Start the game
        startGame()
    }

    func resetGame() {
        players = players.map { player in
            var resetPlayer = player
            resetPlayer.points = 0
            resetPlayer.isEliminated = false
            resetPlayer.completedCycles = 0
            resetPlayer.failedCycles = 0
            return resetPlayer
        }
        currentPlayerIndex = 0
        currentCycle = 1
        currentRound = 1
        turnsInCurrentRound = 0
        gamePhase = .setup
        timeRemaining = 0
        cycleDuration = settings.initialCycleDuration
        isButtonPressed = false
        buttonPressStartTime = nil
    }

    func increaseTemperature() {
        if settings.temperature < 220 {
            settings.temperature += 5
        }
    }

    func decreaseTemperature() {
        if settings.temperature > 150 {
            settings.temperature -= 5
        }
    }
}