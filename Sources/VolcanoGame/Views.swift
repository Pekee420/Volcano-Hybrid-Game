//
//  Views.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var bluetoothManager: BluetoothManager
    
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("🍃 BLAZE 🍃")
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(blazeGreen)
                .padding(.vertical, 12)

            Divider().background(blazeGreen)

            // Standings during game
            if gameState.gamePhase != .setup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🏆 Standings")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(gameState.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                                HStack(spacing: 4) {
                                    Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  \(index + 1)")
                                        .font(.caption2)
                                        .frame(width: 20)

                                    Text(player.name)
                                        .font(.caption)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(player.points)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(player.isEliminated ? .red : .white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(player.id == gameState.currentPlayer?.id ?
                                              blazeGreen.opacity(0.3) : Color.clear)
                                )
                                .opacity(player.isEliminated ? 0.5 : 1.0)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(maxHeight: 150)
                    
                    // Game info
                    VStack(spacing: 4) {
                        Text("Round \(gameState.currentRound)/\(gameState.settings.totalRounds)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("💨 \(String(format: "%.0f", gameState.cycleDuration))s hit")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Text("🌿 Add Players")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()

            // Volcano Connection - Fixed at bottom
            VStack(spacing: 6) {
                Divider().background(blazeGreen)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(BluetoothManager.shared.isConnected ? blazeGreen : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(BluetoothManager.shared.isConnected ? "🌋 Connected" : "🔌 Disconnected")
                        .font(.caption2)
                        .foregroundColor(BluetoothManager.shared.isConnected ? blazeGreen : .red)
                }
                .padding(.top, 6)

                Button(action: {
                    if BluetoothManager.shared.isConnected {
                        BluetoothManager.shared.disconnect()
                    } else {
                        BluetoothManager.shared.startScanning()
                    }
                }) {
                    Text(BluetoothManager.shared.isConnected ? "Disconnect" : "🔍 Connect")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(blazeGreen)
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 160)
        .background(Color.black.opacity(0.3))
    }
}

struct WaitingForTempView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isPumping = false
    @State private var pumpCountdown = 5
    @State private var checkTimer: Timer?
    
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let purpleHaze = Color(red: 0.5, green: 0.2, blue: 0.6)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.1)
    
    var tempDiff: Int {
        abs(bluetoothManager.currentTemperature - gameState.settings.temperature)
    }
    
    var isReady: Bool {
        bluetoothManager.currentTemperature > 0 && tempDiff <= 5
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.05),
                    Color(red: 0.15, green: 0.1, blue: 0.1),
                    Color(red: 0.05, green: 0.1, blue: 0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                Text("🌡️ Waiting for Temperature 🌡️")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(goldLeaf)
                
                // Temperature display
                VStack(spacing: 15) {
                    // Current temp - BIG
                    VStack(spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(bluetoothManager.currentTemperature > 0 ? "\(bluetoothManager.currentTemperature)°C" : "--°C")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundColor(isReady ? blazeGreen : .orange)
                    }
                    
                    // Target temp with controls
                    VStack(spacing: 8) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                if gameState.settings.temperature > 40 {
                                    gameState.settings.temperature -= 5
                                    BluetoothManager.shared.setTemperature(gameState.settings.temperature)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(gameState.settings.temperature)°C")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 150)
                            
                            Button(action: {
                                if gameState.settings.temperature < 230 {
                                    gameState.settings.temperature += 5
                                    BluetoothManager.shared.setTemperature(gameState.settings.temperature)
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(15)
                    
                    // Status
                    if isPumping {
                        VStack(spacing: 10) {
                            Text("🌬️ Pumping Air...")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(blazeGreen)
                            Text("\(pumpCountdown)")
                                .font(.system(size: 60, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(blazeGreen.opacity(0.3))
                        .cornerRadius(15)
                    } else if isReady {
                        Text("✅ Temperature Ready!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(blazeGreen)
                    } else {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text("🔥")
                                    .font(.title2)
                                Text("Heater ON")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            Text("⏳ Heating up...")
                                .font(.title3)
                                .foregroundColor(.orange)
                            if bluetoothManager.currentTemperature > 0 {
                                Text("\(tempDiff)°C to go")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("Waiting for reading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                
                // Cancel button
                Button(action: {
                    checkTimer?.invalidate()
                    BluetoothManager.shared.stopAirPump()
                    gameState.gamePhase = .setup
                }) {
                    Text("❌ Cancel")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .onAppear {
            startHeatingAndCheck()
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }
    
    private func startHeatingAndCheck() {
        // Always try to turn on heater and set temp when entering this view
        print("🔥 Starting heater - temp: \(bluetoothManager.currentTemperature)°C, target: \(gameState.settings.temperature)°C")
        BluetoothManager.shared.startHeater()
        BluetoothManager.shared.setTemperature(gameState.settings.temperature)
        
        // Check temperature every 2 seconds and keep heater on
        var heaterRetryCount = 0
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            heaterRetryCount += 1
            
            // Keep trying to turn heater on every 5 checks (10 seconds) until temp rises
            if heaterRetryCount % 5 == 0 || bluetoothManager.currentTemperature == 0 {
                print("🔥 Heater retry #\(heaterRetryCount) - temp: \(bluetoothManager.currentTemperature)°C")
                BluetoothManager.shared.startHeater()
                BluetoothManager.shared.setTemperature(gameState.settings.temperature)
            }
            
            if isReady && !isPumping {
                startPumping()
            }
        }
    }
    
    private func startPumping() {
        isPumping = true
        pumpCountdown = 5
        BluetoothManager.shared.startAirPump()
        
        // Countdown timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            pumpCountdown -= 1
            if pumpCountdown <= 0 {
                timer.invalidate()
                checkTimer?.invalidate()
                BluetoothManager.shared.stopAirPump()
                
                // Start the game!
                gameState.gamePhase = .preparation
                gameState.timeRemaining = gameState.settings.preparationTime
                SoundManager.shared.playGameStartSound()
                print("🎮 Game started after temp wait!")
            }
        }
    }
}

struct PlayerSetupView: View {
    @ObservedObject var gameState: GameState
    @StateObject private var leaderboard = LeaderboardManager.shared
    @State private var newPlayerName = ""
    
    // 420 Theme Colors
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let purpleHaze = Color(red: 0.5, green: 0.2, blue: 0.6)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.1)

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.05),
                    Color(red: 0.1, green: 0.15, blue: 0.1),
                    Color(red: 0.05, green: 0.1, blue: 0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            HStack(spacing: 40) {
                // Left side - Game Setup
                VStack(spacing: 20) {
                    // Title with 420 vibes
                    VStack(spacing: 4) {
                        Text("🍃 VOLCANO BLAZE 🍃")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [blazeGreen, goldLeaf, blazeGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("4 2 0   G A M E")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(purpleHaze)
                            .tracking(4)
                    }
                    .padding(.bottom, 10)

                    // Players Section
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                TextField("Stoner name", text: $newPlayerName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)

                                Button("🌿 Add") {
                                    if !newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        gameState.settings.singlePlayerMode = false
                                        gameState.addPlayer(name: newPlayerName.trimmingCharacters(in: .whitespaces))
                                        newPlayerName = ""
                                    }
                                }
                                .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                                .buttonStyle(.borderedProminent)
                                .tint(blazeGreen)
                            }

                            if !gameState.players.isEmpty {
                                ForEach(gameState.players.filter { !$0.isAI }) { player in
                                    HStack {
                                        Text("🍀 \(player.name)")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button("✕") {
                                            if let index = gameState.players.firstIndex(where: { $0.id == player.id }) {
                                                gameState.removePlayer(at: index)
                                            }
                                        }
                                        .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Text("🔥 Smokers").font(.headline).foregroundColor(goldLeaf)
                    }
                    .backgroundStyle(Color.black.opacity(0.3))
                    .frame(width: 350)

                // Game Settings Section
                GroupBox {
                    VStack(spacing: 16) {
                        // Rounds
                        HStack {
                            Text("Rounds:")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(gameState.settings.totalRounds)")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            Stepper("", value: $gameState.settings.totalRounds, in: 1...10)
                                .labelsHidden()
                                .frame(width: 80)
                        }
                        
                        // Starting Cycle Length
                        HStack {
                            Text("Starting Duration:")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(gameState.settings.initialCycleDuration))s")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            Stepper("", value: $gameState.settings.initialCycleDuration, in: 3...30, step: 1)
                                .labelsHidden()
                                .frame(width: 80)
                        }
                        
                        // Cycle Increment - now per round
                        HStack {
                            Text("Add per round:")
                                .foregroundColor(.white)
                            Spacer()
                            Text("+\(Int(gameState.settings.cycleIncrement))s")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            Stepper("", value: $gameState.settings.cycleIncrement, in: 0...10, step: 1)
                                .labelsHidden()
                                .frame(width: 80)
                        }
                        
                        // Prep Time
                        HStack {
                            Text("Prep Time:")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(gameState.settings.preparationTime))s")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            Stepper("", value: $gameState.settings.preparationTime, in: 2...10, step: 1)
                                .labelsHidden()
                                .frame(width: 80)
                        }
                        
                        // Hardcore Mode
                        Toggle("Hardcore Mode", isOn: $gameState.settings.hardcoreMode)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                } label: {
                    Text("⚙️ Settings").font(.headline).foregroundColor(goldLeaf)
                }
                .backgroundStyle(Color.black.opacity(0.3))
                .frame(width: 350)

                    Spacer()

                    // Start Button logic
                    let humanPlayerCount = gameState.players.filter({ !$0.isAI }).count
                    
                    if !BluetoothManager.shared.isConnected {
                        HStack {
                            Text("🔌 Connect your Volcano to blaze")
                                .foregroundColor(.orange)
                                .font(.title3)
                        }
                    } else if humanPlayerCount >= 2 {
                        // 2+ players: show normal Start Game button
                        Button(action: {
                            gameState.startGame()
                        }) {
                            HStack {
                                Text("🔥")
                                Text("LIGHT IT UP")
                                    .fontWeight(.black)
                                Text("🔥")
                            }
                            .font(.title2)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [blazeGreen, purpleHaze],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: blazeGreen.opacity(0.5), radius: 10)
                        }
                        .buttonStyle(.plain)
                    } else if humanPlayerCount == 1 {
                        // Easter egg: clicking text secretly starts with Snoop
                        Button(action: {
                            gameState.startGame() // Will auto-add Snoop Dogg
                        }) {
                            Text("Need 2 smokers to start the sesh")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 0 players
                        Text("Add smokers to start")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                // Right side - Leaderboard
                VStack(spacing: 15) {
                    Text("🏆 Hall of Flame 🏆")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(goldLeaf)
                    
                    if leaderboard.highScores.isEmpty {
                        Text("No legends yet!")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(Array(leaderboard.highScores.prefix(15).enumerated()), id: \.element.id) { index, score in
                                    HStack {
                                        Text(index < 3 ? (index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉") : "\(index + 1).")
                                            .frame(width: 30)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    
                                        Text(score.playerName)
                                            .fontWeight(index < 3 ? .bold : .regular)
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                    
                                        Spacer()
                                    
                                        Text("\(score.score)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(index == 0 ? .yellow : .white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(index == 0 ? Color.yellow.opacity(0.1) : Color.clear)
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    
                    if !leaderboard.highScores.isEmpty {
                        Button("🗑️ Clear Hall of Flame") {
                            leaderboard.clearHighScores()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .padding()
                .frame(width: 250)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(purpleHaze.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct GameFinishedView: View {
    @ObservedObject var gameState: GameState
    
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let purpleHaze = Color(red: 0.5, green: 0.2, blue: 0.6)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.1)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.05),
                    Color(red: 0.1, green: 0.15, blue: 0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🍃 SESH COMPLETE 🍃")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [goldLeaf, blazeGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("\(gameState.settings.totalRounds) Rotations Complete!")
                    .font(.title2)
                    .foregroundColor(.gray)

                if let winner = gameState.rankedPlayers.first {
                    VStack(spacing: 15) {
                        Text("👑 TOP SMOKER 👑")
                            .font(.title)
                            .foregroundColor(goldLeaf)
                        
                        Text(winner.name)
                            .font(.system(size: 56, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [blazeGreen, purpleHaze],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("\(winner.points) points")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [blazeGreen, goldLeaf, purpleHaze],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                    )
                    .shadow(color: blazeGreen.opacity(0.3), radius: 20)
                }
                
                // Full Leaderboard
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔥 Final Standings")
                        .font(.headline)
                        .foregroundColor(goldLeaf)
                        .padding(.bottom, 5)
                    
                    ForEach(Array(gameState.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "  \(index + 1).")
                                .font(.title2)
                                .frame(width: 40)
                            
                            Text(player.name)
                                .font(.title3)
                                .fontWeight(index == 0 ? .bold : .regular)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(player.points) pts")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(index == 0 ? blazeGreen : .gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .frame(width: 350)

                Button(action: {
                    gameState.resetGame()
                }) {
                    HStack {
                        Text("🔄")
                        Text("ANOTHER ROUND")
                            .fontWeight(.black)
                        Text("🔄")
                    }
                    .font(.title2)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [blazeGreen, purpleHaze],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: purpleHaze.opacity(0.5), radius: 10)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .onAppear {
            // Play "Smoke Weed Every Day" winner sound!
            SoundManager.shared.playWinnerSound()
        }
    }
}

struct GameView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var bluetoothManager: BluetoothManager
    
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let purpleHaze = Color(red: 0.5, green: 0.2, blue: 0.6)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.1)
    let darkGanja = Color(red: 0.05, green: 0.08, blue: 0.05)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / 600 // Base scale on 600pt
            let bubbleSize = 200 * scale
            let fontSize = scale
            
            ZStack {
                // Dark ganja background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.02, green: 0.05, blue: 0.02),
                        Color(red: 0.08, green: 0.12, blue: 0.06),
                        Color(red: 0.02, green: 0.05, blue: 0.02)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main game content
                VStack(spacing: 0) {
                    // Top: Round and player info
                    VStack(spacing: 6 * scale) {
                        Text("Round \(gameState.currentRound) of \(gameState.settings.totalRounds)")
                            .font(.system(size: 14 * fontSize))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12 * scale)
                            .padding(.vertical, 4 * scale)
                            .background(Color.orange.opacity(0.5))
                            .cornerRadius(6 * scale)
                        
                        if let player = gameState.currentPlayer {
                            Text(player.name)
                                .font(.system(size: 28 * fontSize, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16 * scale)
                                .padding(.vertical, 6 * scale)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8 * scale)

                            Text("\(player.points) points")
                                .font(.system(size: 16 * fontSize, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.top, 20 * scale)

                Spacer()

                // Center: Main game bubble
                ZStack {
                    switch gameState.gamePhase {
                    case .preparation:
                        // Orange prep bubble
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: bubbleSize, height: bubbleSize)
                            .overlay(
                                VStack(spacing: 8 * scale) {
                                    Text("🍃")
                                        .font(.system(size: 40 * fontSize))
                                    Text("GET READY!")
                                        .font(.system(size: 18 * fontSize, weight: .black))
                                        .foregroundColor(.white)
                                    Text("Hold SPACE")
                                        .font(.system(size: 12 * fontSize))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )

                    case .active:
                        // Green/red bubble based on button state
                        Circle()
                            .fill(gameState.isButtonPressed ? blazeGreen.opacity(0.9) : Color.red.opacity(0.8))
                            .frame(width: bubbleSize, height: bubbleSize)
                            .overlay(
                                VStack(spacing: 8 * scale) {
                                    Text(gameState.isButtonPressed ? "🔥" : "⚠️")
                                        .font(.system(size: 50 * fontSize))
                                    Text(gameState.isButtonPressed ? "BLAZING!" : "PRESS!")
                                        .font(.system(size: 18 * fontSize, weight: .black))
                                        .foregroundColor(.white)
                                }
                            )

                    case .completed:
                        Circle()
                            .fill(blazeGreen.opacity(0.9))
                            .frame(width: bubbleSize * 1.1, height: bubbleSize * 1.1)
                            .overlay(
                                VStack(spacing: 4 * scale) {
                                    Text("✅")
                                        .font(.system(size: 30 * fontSize))
                                    Text(String(format: "%.1fs", gameState.lastDrawTime))
                                        .font(.system(size: 48 * fontSize, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("SUCCESS!")
                                        .font(.system(size: 12 * fontSize, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("+\(gameState.lastPointsEarned) pts")
                                        .font(.system(size: 18 * fontSize, weight: .black))
                                        .foregroundColor(.yellow)
                                }
                            )

                    case .failed:
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: bubbleSize * 1.1, height: bubbleSize * 1.1)
                            .overlay(
                                VStack(spacing: 4 * scale) {
                                    Text("💨")
                                        .font(.system(size: 30 * fontSize))
                                    Text(String(format: "%.1fs", gameState.lastDrawTime))
                                        .font(.system(size: 48 * fontSize, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("FAILED!")
                                        .font(.system(size: 12 * fontSize, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                    if gameState.lastPointsEarned > 0 {
                                        Text("+\(gameState.lastPointsEarned) pts")
                                            .font(.system(size: 18 * fontSize, weight: .black))
                                            .foregroundColor(.yellow)
                                    } else {
                                        Text("0 pts")
                                            .font(.system(size: 18 * fontSize, weight: .black))
                                            .foregroundColor(.gray)
                                    }
                                }
                            )
                        
                    case .eliminated:
                        Circle()
                            .fill(Color.black)
                            .frame(width: bubbleSize, height: bubbleSize)
                            .overlay(Circle().stroke(Color.red, lineWidth: 4 * scale))
                            .overlay(
                                VStack(spacing: 8 * scale) {
                                    Text("💀")
                                        .font(.system(size: 50 * fontSize))
                                    Text("ELIMINATED")
                                        .font(.system(size: 18 * fontSize, weight: .black))
                                        .foregroundColor(.red)
                                    if let name = gameState.eliminatedPlayerName {
                                        Text(name)
                                            .font(.system(size: 14 * fontSize))
                                            .foregroundColor(.white)
                                    }
                                }
                            )

                    case .paused:
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: bubbleSize, height: bubbleSize)
                            .overlay(
                                VStack(spacing: 8 * scale) {
                                    Text("⏭️")
                                        .font(.system(size: 40 * fontSize))
                                    Text("Next Up:")
                                        .font(.system(size: 12 * fontSize))
                                        .foregroundColor(.white.opacity(0.8))
                                    if let upcomingPlayer = gameState.upcomingPlayer {
                                        Text(upcomingPlayer.name)
                                            .font(.system(size: 20 * fontSize, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            )

                    default:
                        EmptyView()
                    }
                }

                Spacer()

                // Countdown bar (only during active phases)
                if gameState.gamePhase == .active || gameState.gamePhase == .preparation {
                    VStack(spacing: 6 * scale) {
                        Text(gameState.gamePhase == .preparation ? "Prep Time" : "Hold Time")
                            .font(.system(size: 12 * fontSize))
                            .foregroundColor(.gray)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8 * scale)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 300 * scale, height: 20 * scale)

                            RoundedRectangle(cornerRadius: 8 * scale)
                                .fill(gameState.gamePhase == .preparation ? Color.orange : blazeGreen)
                                .frame(width: max(0, 300 * scale * CGFloat(gameState.timeRemaining / max(1, gameState.gamePhase == .preparation ? gameState.settings.preparationTime : gameState.cycleDuration))), height: 20 * scale)
                        }

                        Text(String(format: "%.1f", max(0, gameState.timeRemaining)))
                            .font(.system(size: 28 * fontSize, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .padding(.bottom, 20 * scale)
                }

                // Bottom: Temperature and Stop button
                HStack(spacing: 30 * scale) {
                    // Temperature display
                    VStack(spacing: 4 * scale) {
                        Text("🌡️ TEMP")
                            .font(.system(size: 10 * fontSize))
                            .foregroundColor(.gray)
                        
                        Text(bluetoothManager.currentTemperature > 0 ? "\(bluetoothManager.currentTemperature)°C" : "--")
                            .font(.system(size: 22 * fontSize, weight: .bold))
                            .foregroundColor(.orange)
                        
                        HStack(spacing: 15 * scale) {
                            Button(action: {
                                BluetoothManager.shared.decreaseTemperature()
                                if gameState.settings.temperature > 40 {
                                    gameState.settings.temperature -= 5
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20 * fontSize))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("\(gameState.settings.temperature)°")
                                .font(.system(size: 12 * fontSize))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                BluetoothManager.shared.increaseTemperature()
                                if gameState.settings.temperature < 230 {
                                    gameState.settings.temperature += 5
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20 * fontSize))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 15 * scale)
                    .padding(.vertical, 10 * scale)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10 * scale)
                    
                    // Stop button - costs 10 points!
                    Button(action: {
                        // Deduct 10 points from current player
                        if let currentPlayer = gameState.currentPlayer,
                           let index = gameState.players.firstIndex(where: { $0.id == currentPlayer.id }) {
                            gameState.players[index].points -= 10
                        }
                        gameState.resetGame()
                    }) {
                        VStack(spacing: 2 * scale) {
                            Text("🛑 STOP")
                                .font(.system(size: 16 * fontSize, weight: .semibold))
                                .foregroundColor(.white)
                            Text("-10 pts")
                                .font(.system(size: 10 * fontSize))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 20 * scale)
                        .padding(.vertical, 10 * scale)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10 * scale)
                    }
                }
                .padding(.bottom, 20 * scale)
                } // End main VStack
                
                // Floating Leaderboard - Top Left
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8 * scale) {
                            Text("🏆 Standings")
                                .font(.system(size: 16 * fontSize, weight: .bold))
                                .foregroundColor(goldLeaf)
                            
                            VStack(spacing: 4 * scale) {
                                ForEach(Array(gameState.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                                    HStack(spacing: 6 * scale) {
                                        Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "\(index + 1).")
                                            .font(.system(size: 12 * fontSize))
                                            .frame(width: 22 * scale)
                                        
                                        Text(player.name)
                                            .font(.system(size: 12 * fontSize, weight: player.id == gameState.currentPlayer?.id ? .bold : .regular))
                                            .foregroundColor(player.id == gameState.currentPlayer?.id ? goldLeaf : .white)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(player.points)")
                                            .font(.system(size: 12 * fontSize, weight: .bold))
                                            .foregroundColor(player.isEliminated ? .red : (index == 0 ? .yellow : .white))
                                    }
                                    .padding(.horizontal, 8 * scale)
                                    .padding(.vertical, 3 * scale)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4 * scale)
                                            .fill(player.id == gameState.currentPlayer?.id ? blazeGreen.opacity(0.3) : Color.clear)
                                    )
                                    .opacity(player.isEliminated ? 0.5 : 1.0)
                                }
                            }
                            
                            // Game info
                            HStack {
                                Text("💨 \(String(format: "%.0f", gameState.cycleDuration))s")
                                    .font(.system(size: 10 * fontSize))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 4 * scale)
                        }
                        .padding(12 * scale)
                        .frame(width: 180 * scale)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12 * scale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12 * scale)
                                .stroke(
                                    LinearGradient(
                                        colors: [blazeGreen, purpleHaze, blazeGreen],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2 * scale
                                )
                        )
                        .shadow(color: blazeGreen.opacity(0.4), radius: 10 * scale)
                        
                        Spacer()
                    }
                    .padding(.leading, 15 * scale)
                    .padding(.top, 15 * scale)
                    
                    Spacer()
                }
            } // End ZStack
        } // End GeometryReader
    }
}

struct TemperatureControlView: View {
    @EnvironmentObject var gameState: GameState
    @StateObject private var bluetoothManager = BluetoothManager.shared

    var body: some View {
        VStack(spacing: 4) {
            // Actual temperature - BIG
            Text(bluetoothManager.currentTemperature > 0 ? "\(bluetoothManager.currentTemperature)°C" : "--°C")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(bluetoothManager.isConnected ? .orange : .secondary)
            
            // Set/Target temperature - small
            Text("Set: \(gameState.settings.temperature)°C")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                Button(action: {
                    BluetoothManager.shared.decreaseTemperature()
                    if gameState.settings.temperature > 40 {
                        gameState.settings.temperature -= 5
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(bluetoothManager.isConnected ? .blue : .gray)
                }
                .disabled(!bluetoothManager.isConnected)

                Button(action: {
                    BluetoothManager.shared.increaseTemperature()
                    if gameState.settings.temperature < 230 {
                        gameState.settings.temperature += 5
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(bluetoothManager.isConnected ? .red : .gray)
                }
                .disabled(!bluetoothManager.isConnected)
            }
        }
        .onAppear {
            if bluetoothManager.isConnected {
                BluetoothManager.shared.readTemperature()
            }
        }
    }
}

struct StopGameButton: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        Button(action: {
            gameState.resetGame()
        }) {
            Text("Stop Game")
                .font(.headline)
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
