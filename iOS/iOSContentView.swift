//
//  iOSContentView.swift
//  VolcanoGame iOS
//

import SwiftUI

struct iOSContentView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var timer: Timer?
    @State private var hasInitialized = false
    
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.05, blue: 0.02), Color(red: 0.08, green: 0.12, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
            switch gameState.gamePhase {
            case .setup:
                SetupView()
            case .waitingForTemp:
                WaitingTempView()
            case .preparation, .active:
                ActiveGameView(onTimerTick: handleTimerTick)
            case .completed, .failed:
                ResultView()
            case .paused, .eliminated:
                PausedView()
            case .finished:
                FinishedView()
            }
        }
        .onAppear {
            // Bluetooth is now initialized at app level with delay
            hasInitialized = true
        }
    }
    
    private func handleTimerTick() {
        guard gameState.gamePhase == .preparation || gameState.gamePhase == .active else { return }
        gameState.timeRemaining -= 0.1
        if gameState.timeRemaining <= 0 {
            handleTimerEnd()
        }
    }
    
    private func handleTimerEnd() {
        if gameState.gamePhase == .preparation {
            // CHECK: Is player holding the button when prep ends?
            if gameState.isButtonPressed {
                // Good - they're ready, start the active phase
                gameState.startCycle()
            } else {
                // NOT holding button - FAIL them immediately!
                gameState.completeCycle(success: false, drawTime: 0)
            }
        } else if gameState.gamePhase == .active {
            if gameState.isButtonPressed {
                let drawTime = gameState.buttonPressStartTime != nil ?
                    Date().timeIntervalSince(gameState.buttonPressStartTime!) : gameState.cycleDuration
                BluetoothManager.shared.stopAirPump()
                gameState.completeCycle(success: true, drawTime: drawTime)
            } else {
                gameState.completeCycle(success: false, drawTime: 0)
            }
        }
    }
}

// MARK: - Setup View with ALL Settings
struct SetupView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @StateObject private var leaderboard = LeaderboardManager.shared
    @State private var newName = ""
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let purpleHaze = Color(red: 0.5, green: 0.2, blue: 0.6)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text("🌋").font(.system(size: 50))
                    Text("VOLCANO BLAZE").font(.title).fontWeight(.black).foregroundColor(blazeGreen)
                    
                    // High Score Display
                    if let topScore = leaderboard.highScores.first {
                        HStack(spacing: 6) {
                            Text("👑")
                            Text("\(topScore.playerName): \(topScore.score) pts")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(goldLeaf)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 10)
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(bluetoothManager.isConnected ? blazeGreen : Color.red)
                        .frame(width: 12, height: 12)
                    Text(bluetoothManager.isConnected ? "Connected" : bluetoothManager.connectionState)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    if !bluetoothManager.isConnected {
                        Button("Scan") {
                            bluetoothManager.startScanning()
                        }
                        .font(.caption)
                        .foregroundColor(blazeGreen)
                    }
                }
                .padding(.horizontal)
                
                // Add Player Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("PLAYERS").font(.caption).foregroundColor(.gray)
                    HStack {
                        TextField("Enter name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.done)
                            .onSubmit {
                                if !newName.isEmpty {
                                    gameState.addPlayer(name: newName)
                                    newName = ""
                                }
                            }
                        Button(action: {
                            if !newName.isEmpty {
                                gameState.addPlayer(name: newName)
                                newName = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(blazeGreen)
                        }
                    }
                    
                    // Player list
                    ForEach(Array(gameState.players.enumerated()), id: \.element.id) { _, player in
                        HStack {
                            Text(player.name).foregroundColor(.white)
                            Spacer()
                            Button(action: { gameState.removePlayer(id: player.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if gameState.players.isEmpty {
                        Text("Add at least 2 players to start")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // Game Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚙️ GAME SETTINGS").font(.caption).foregroundColor(.gray)
                    
                    // Rounds
                    SettingRow(title: "Rounds", value: "\(gameState.settings.totalRounds)") {
                        Stepper("", value: $gameState.settings.totalRounds, in: 1...20)
                            .labelsHidden()
                    }
                    
                    // Starting Duration
                    SettingRow(title: "Starting Duration", value: "\(Int(gameState.settings.initialCycleDuration))s") {
                        Stepper("", value: Binding(
                            get: { Int(gameState.settings.initialCycleDuration) },
                            set: { gameState.settings.initialCycleDuration = TimeInterval($0) }
                        ), in: 3...30)
                        .labelsHidden()
                    }
                    
                    // Time Added Per Round
                    SettingRow(title: "Add Per Round", value: "+\(Int(gameState.settings.cycleIncrement))s") {
                        Stepper("", value: Binding(
                            get: { Int(gameState.settings.cycleIncrement) },
                            set: { gameState.settings.cycleIncrement = TimeInterval($0) }
                        ), in: 0...10)
                        .labelsHidden()
                    }
                    
                    // Preparation Time
                    SettingRow(title: "Prep Time", value: "\(Int(gameState.settings.preparationTime))s") {
                        Stepper("", value: Binding(
                            get: { Int(gameState.settings.preparationTime) },
                            set: { gameState.settings.preparationTime = TimeInterval($0) }
                        ), in: 2...15)
                        .labelsHidden()
                    }
                    
                    // Hardcore Mode
                    HStack {
                        Text("💀 Hardcore Mode")
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $gameState.settings.hardcoreMode)
                            .labelsHidden()
                            .tint(purpleHaze)
                    }
                    .padding(.vertical, 4)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // Temperature Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("🌡️ TEMPERATURE").font(.caption).foregroundColor(.gray)
                    
                    HStack {
                        Text("Target Temp")
                            .foregroundColor(.white)
                        Spacer()
                        
                        Button(action: {
                            if gameState.settings.temperature > 40 {
                                gameState.settings.temperature -= 5
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        
                        Text("\(gameState.settings.temperature)°C")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .frame(width: 70)
                        
                        Button(action: {
                            if gameState.settings.temperature < 230 {
                                gameState.settings.temperature += 5
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if bluetoothManager.currentTemperature > 0 {
                        HStack {
                            Text("Current:")
                                .foregroundColor(.gray)
                            Text("\(bluetoothManager.currentTemperature)°C")
                                .foregroundColor(.orange)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // Start Button
                Button(action: {
                    if gameState.players.count >= 1 {
                        gameState.startGame()
                    }
                }) {
                    HStack {
                        Text("🔥")
                        Text("START GAME")
                            .fontWeight(.black)
                        Text("🔥")
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [blazeGreen, blazeGreen.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(15)
                }
                .disabled(gameState.players.isEmpty)
                .opacity(gameState.players.isEmpty ? 0.5 : 1)
                .padding(.top, 10)
            }
            .padding()
        }
    }
}

// Helper view for settings rows
struct SettingRow<Content: View>: View {
    let title: String
    let value: String
    let control: () -> Content
    
    init(title: String, value: String, @ViewBuilder control: @escaping () -> Content) {
        self.title = title
        self.value = value
        self.control = control
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.orange)
                .fontWeight(.semibold)
            control()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Waiting Temp View with Controls
struct WaitingTempView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var checkTimer: Timer?
    @State private var isPumping = false
    @State private var pumpCountdown = 5
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var tempDiff: Int {
        abs(gameState.settings.temperature - bluetoothManager.currentTemperature)
    }
    
    var isReady: Bool {
        bluetoothManager.currentTemperature > 0 && tempDiff <= 5
    }
    
    var body: some View {
        VStack(spacing: 25) {
            // Title changes based on state
            if isPumping {
                Text("🌬️ PUMPING AIR...")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(blazeGreen)
                
                Text("\(pumpCountdown)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text(isReady ? "✅ READY!" : "🔥 HEATING UP 🔥")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(isReady ? blazeGreen : .orange)
                
                // Current Temperature - BIG
                VStack(spacing: 4) {
                    Text(bluetoothManager.currentTemperature > 0 ? "\(bluetoothManager.currentTemperature)°C" : "---")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(isReady ? blazeGreen : .orange)
                    
                    if bluetoothManager.currentTemperature > 0 && !isReady {
                        Text("\(tempDiff)° to go")
                            .font(.headline)
                            .foregroundColor(.gray)
                    } else if isReady && !isPumping {
                        Text("Temperature reached!")
                            .font(.headline)
                            .foregroundColor(blazeGreen)
                    }
                }
            }
            
            // Progress indicator (only when heating, not pumping)
            if !isPumping {
                if bluetoothManager.currentTemperature > 0 {
                    let progress = min(1.0, Double(bluetoothManager.currentTemperature) / Double(gameState.settings.temperature))
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: isReady ? blazeGreen : .orange))
                        .scaleEffect(x: 1, y: 2)
                        .padding(.horizontal, 40)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(1.5)
                }
            }
            
            // Temperature Controls
            VStack(spacing: 12) {
                Text("TARGET TEMPERATURE")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 30) {
                    Button(action: {
                        if gameState.settings.temperature > 40 {
                            gameState.settings.temperature -= 5
                            BluetoothManager.shared.setTemperature(gameState.settings.temperature)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    
                    Text("\(gameState.settings.temperature)°C")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 120)
                    
                    Button(action: {
                        if gameState.settings.temperature < 230 {
                            gameState.settings.temperature += 5
                            BluetoothManager.shared.setTemperature(gameState.settings.temperature)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))
            .cornerRadius(15)
            
            Spacer()
            
            // Cancel Button
            Button(action: {
                checkTimer?.invalidate()
                BluetoothManager.shared.stopAirPump()
                gameState.gamePhase = .setup
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .onAppear {
            startHeatingAndCheck()
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }
    
    private func startHeatingAndCheck() {
        // Turn on heater and set temperature
        guard gameState.gamePhase == .waitingForTemp else {
            print("⚠️ Skipping heater start (not waitingForTemp) - phase: \(gameState.gamePhase)")
            return
        }
        if !BluetoothManager.shared.heaterIsOn {
            BluetoothManager.shared.startHeater()
        } else {
            print("⚠️ Skipping heater start (heaterIsOn=true)")
        }
        BluetoothManager.shared.setTemperature(gameState.settings.temperature)

        // Check temperature every 2 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard gameState.gamePhase == .waitingForTemp else {
                print("⚠️ Exiting heater retry (iOS) - phase changed to \(gameState.gamePhase)")
                checkTimer?.invalidate()
                return
            }
            
            // When temperature is ready, start pumping sequence
            if isReady && !isPumping {
                startPumping()
            }
        }
    }
    
    private func startPumping() {
        isPumping = true
        pumpCountdown = 5
        BluetoothManager.shared.startAirPump()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        // Countdown timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            pumpCountdown -= 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            if pumpCountdown <= 0 {
                timer.invalidate()
                checkTimer?.invalidate()
                BluetoothManager.shared.stopAirPump()
                
                // Start the game!
                gameState.gamePhase = .preparation
                gameState.timeRemaining = gameState.settings.preparationTime
                SoundManager.shared.playGameStartSound()
            }
        }
    }
}

// MARK: - Active Game View
struct ActiveGameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var gameTimer: Timer?
    let onTimerTick: () -> Void
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        VStack(spacing: 15) {
            // Top info bar
            HStack {
                // Round info
                VStack(alignment: .leading) {
                    Text("Round \(gameState.currentRound)/\(gameState.settings.totalRounds)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(Int(gameState.cycleDuration))s cycle")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Temp indicator
                HStack(spacing: 4) {
                    Text("🌡️")
                    Text(bluetoothManager.currentTemperature > 0 ? "\(bluetoothManager.currentTemperature)°" : "--")
                        .foregroundColor(.orange)
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            // Player info
            if let player = gameState.currentPlayer {
                VStack(spacing: 4) {
                    Text(player.name)
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("\(player.points) points")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
            }
            
            // Phase indicator
            Text(gameState.gamePhase == .preparation ? "GET READY!" : "HOLD IT!")
                .font(.headline)
                .foregroundColor(gameState.gamePhase == .preparation ? .orange : blazeGreen)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            
            Spacer()
            
            // Hold button
            HoldButtonView()
            
            Spacer()
            
            // Timer display
            Text(String(format: "%.1f", max(0, gameState.timeRemaining)))
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 16)
                    
                    let maxTime = gameState.gamePhase == .preparation ? gameState.settings.preparationTime : gameState.cycleDuration
                    let progress = max(0, gameState.timeRemaining / max(1, maxTime))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gameState.gamePhase == .preparation ? Color.orange : blazeGreen)
                        .frame(width: geo.size.width * CGFloat(progress), height: 16)
                }
            }
            .frame(height: 16)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .padding(.top)
        .onAppear {
            // Start timer only when this view appears
            gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                onTimerTick()
            }
        }
        .onDisappear {
            gameTimer?.invalidate()
            gameTimer = nil
        }
    }
}

// MARK: - Hold Button
struct HoldButtonView: View {
    @EnvironmentObject var gameState: GameState
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: gameState.isButtonPressed ? [blazeGreen, blazeGreen.opacity(0.6)] : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Text(gameState.isButtonPressed ? "🔥" : "👆")
                        .font(.system(size: 50))
                    Text(gameState.isButtonPressed ? "HOLDING" : "HOLD")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            )
            .overlay(
                Circle()
                    .stroke(gameState.isButtonPressed ? blazeGreen : Color.gray, lineWidth: 4)
            )
            .scaleEffect(gameState.isButtonPressed ? 1.1 : 1.0)
            .shadow(color: gameState.isButtonPressed ? blazeGreen.opacity(0.6) : .clear, radius: 20)
            .animation(.spring(response: 0.3), value: gameState.isButtonPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !gameState.isButtonPressed {
                            gameState.isButtonPressed = true
                            if gameState.gamePhase == .active {
                                gameState.buttonPressStartTime = Date()
                                BluetoothManager.shared.startAirPump()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        if gameState.isButtonPressed {
                            gameState.isButtonPressed = false
                            if gameState.gamePhase == .active && gameState.timeRemaining > 0 {
                                let drawTime = gameState.buttonPressStartTime != nil ?
                                    Date().timeIntervalSince(gameState.buttonPressStartTime!) : 0
                                BluetoothManager.shared.stopAirPump()
                                gameState.completeCycle(success: false, drawTime: drawTime)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            )
    }
}

// MARK: - Result View
struct ResultView: View {
    @EnvironmentObject var gameState: GameState
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(gameState.gamePhase == .completed ? "✅" : "💨")
                .font(.system(size: 70))
            
            Text(String(format: "%.1fs", gameState.lastDrawTime))
                .font(.system(size: 60, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text(gameState.gamePhase == .completed ? "SUCCESS!" : "FAILED!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(gameState.gamePhase == .completed ? blazeGreen : .red)
            
            if gameState.lastPointsEarned > 0 {
                Text("+\(gameState.lastPointsEarned) pts")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            } else {
                Text("0 pts")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// MARK: - Paused View
struct PausedView: View {
    @EnvironmentObject var gameState: GameState
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if gameState.gamePhase == .eliminated {
                Text("💀")
                    .font(.system(size: 70))
                Text("ELIMINATED")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(.red)
                if let name = gameState.eliminatedPlayerName {
                    Text(name)
                        .font(.title2)
                        .foregroundColor(.white)
                }
            } else {
                Text("⏭️")
                    .font(.system(size: 60))
                Text("NEXT UP")
                    .font(.headline)
                    .foregroundColor(.gray)
                if let next = gameState.upcomingPlayer {
                    Text(next.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Finished View
struct FinishedView: View {
    @EnvironmentObject var gameState: GameState
    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    let goldLeaf = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("🍃 SESH COMPLETE 🍃")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(.orange)
                    .padding(.top, 20)
                    .onAppear {
                        // Play winner sound!
                        SoundManager.shared.playWinnerSound()
                    }
                
                // Winner
                if let winner = gameState.rankedPlayers.first {
                    VStack(spacing: 8) {
                        Text("👑")
                            .font(.system(size: 50))
                        Text(winner.name)
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(goldLeaf)
                        Text("\(winner.points) points")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                }
                
                // Leaderboard
                VStack(spacing: 8) {
                    ForEach(Array(gameState.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "\(index + 1).")
                                .frame(width: 30)
                            Text(player.name)
                                .foregroundColor(player.isEliminated ? .gray : .white)
                            Spacer()
                            Text("\(player.points)")
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .opacity(player.isEliminated ? 0.6 : 1)
                    }
                }
                .padding()
                
                // Play Again
                Button(action: {
                    gameState.resetGame()
                }) {
                    HStack {
                        Text("🔄")
                        Text("PLAY AGAIN")
                            .fontWeight(.black)
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(blazeGreen)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    iOSContentView()
        .environmentObject(GameState())
        .environmentObject(BluetoothManager.shared)
}
