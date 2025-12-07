//
//  ContentView.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import SwiftUI
import AppKit
import Carbon
import CoreGraphics

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @State private var timer: Timer?
    @State private var showingSettings = false
    @State private var keyMonitor: Any?
    @State private var debugLog: [String] = []

    let blazeGreen = Color(red: 0.0, green: 0.6, blue: 0.2)
    
    var body: some View {
        let connected = bluetoothManager.isConnected
        print("🎨 ContentView rendering - connected: \(connected), state: \(bluetoothManager.connectionState)")
        return ZStack {
            // Main content area
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            if !connected {
                // Show connection prompt when not connected
                VStack(spacing: 20) {
                    Text("🔗 Connect to Volcano Device")
                        .font(.title)
                        .foregroundColor(.orange)

                    // BIG status display
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(connected ? Color.green.opacity(0.2) :
                                 bluetoothManager.connectionState == "Connecting..." ? Color.yellow.opacity(0.2) :
                                 Color.red.opacity(0.2))
                            .frame(height: 60)

                        VStack {
                            Text(bluetoothManager.connectionState)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(connected ? .green :
                                               bluetoothManager.connectionState == "Connecting..." ? .orange : .red)

                            if bluetoothManager.isScanning {
                                Text("🔍 Scanning...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if !bluetoothManager.isScanning && bluetoothManager.connectionState == "Not Connected" {
                        Button("🔍 SCAN FOR DEVICES") {
                            print("🚀 Scan button pressed")
                            bluetoothManager.startScanning()
                        }
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(40)
            } else {
                switch gameState.gamePhase {
                case .setup:
                    PlayerSetupView(gameState: gameState)
                case .waitingForTemp:
                    WaitingForTempView(gameState: gameState, bluetoothManager: bluetoothManager)
                case .preparation, .active, .completed, .failed, .paused, .eliminated:
                    GameView(gameState: gameState, bluetoothManager: bluetoothManager)
                case .finished:
                    GameFinishedView(gameState: gameState)
                }
            }
            
            // Bottom-left connection status (always visible when connected and playing)
            if connected && gameState.gamePhase != .setup && gameState.gamePhase != .finished {
                VStack {
                    Spacer()
                    HStack {
                        // Connection indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(blazeGreen)
                                .frame(width: 8, height: 8)
                            Text("🌋 Connected")
                                .font(.caption2)
                                .foregroundColor(blazeGreen)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.leading, 15)
                    .padding(.bottom, 15)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            print("🎨 ContentView appeared")
            startTimer()
            setupGlobalKeyMonitoring()

            // Trigger the Bluetooth fix that normally happens when adding a player
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔧 Triggering Bluetooth fix on ContentView appear...")
                // This simulates the UI interaction that makes Bluetooth work
                NotificationCenter.default.post(name: NSNotification.Name("TriggerBluetoothFix"), object: nil)
                print("🔧 Bluetooth fix triggered")
            }
        }
        .onDisappear {
            timer?.invalidate()
            stopGlobalKeyMonitoring()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(gameState: gameState)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateGame()
        }
    }

    private func updateGame() {
        guard gameState.gamePhase != .setup && gameState.gamePhase != .finished else { return }

        gameState.timeRemaining -= 0.1

        if gameState.timeRemaining <= 0 {
            handleTimerExpiration()
        }
    }

    private func handleTimerExpiration() {
        switch gameState.gamePhase {
        case .preparation:
            // Check if player pressed button during preparation (got ready)
            if gameState.isButtonPressed {
                // Player is ready, start the active cycle
                gameState.startCycle()
            } else {
                // Player never got ready - 0 points
                gameState.completeCycle(success: false, drawTime: 0)
            }
        case .active:
            if gameState.isButtonPressed {
                // Calculate how long the button was held during active phase
                let drawTime = gameState.buttonPressStartTime != nil ?
                    Date().timeIntervalSince(gameState.buttonPressStartTime!) : 0
                gameState.completeCycle(success: true, drawTime: drawTime)
            } else {
                // This shouldn't happen in active phase, but just in case
                gameState.completeCycle(success: false, drawTime: 0)
            }
        case .paused:
            gameState.nextPlayer()
            gameState.startNewCycle()
        case .completed, .failed:
            // Handled by completeCycle method
            break
        default:
            break
        }
    }

    private func logToFile(_ message: String) {
        debugLog.append("\(Date()): \(message)")
        if debugLog.count > 100 { // Keep only last 100 entries
            debugLog.removeFirst()
        }

        // Also write to a debug file
        let logMessage = "\(Date()): \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            let fileURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("VolcanoGame_Debug.log")
            if let fileURL = fileURL {
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: fileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    } else {
                        try data.write(to: fileURL)
                    }
                } catch {
                    print("❌ Failed to write debug log: \(error)")
                }
            }
        }
    }

    // MARK: - Spacebar Input Handling

    @State private var spacebarIsDown = false

    private func setupGlobalKeyMonitoring() {
        print("🎹 Setting up global spacebar monitoring")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.keyCode == 49 { // Spacebar key code
                let isKeyDown = event.type == .keyDown
                
                // Ignore key repeat events (isARepeat is true for repeated keyDown)
                if isKeyDown && event.isARepeat {
                    return nil // Consume repeated press events (no beep)
                }
                
                self.handleSpacebarEvent(isPressed: isKeyDown)
                return nil // Consume spacebar events (no beep)
            }
            return event
        }
    }

    private func stopGlobalKeyMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
            print("🎹 Stopped global spacebar monitoring")
        }
    }

    private func handleSpacebarEvent(isPressed: Bool) {
        // Skip if state hasn't changed
        if isPressed == spacebarIsDown {
            return
        }
        spacebarIsDown = isPressed
        
        print("🎹 Spacebar \(isPressed ? "DOWN" : "UP") - Phase: \(gameState.gamePhase)")
        logToFile("🎹 Spacebar \(isPressed ? "DOWN" : "UP") - Phase: \(gameState.gamePhase)")

        guard gameState.gamePhase == .preparation || gameState.gamePhase == .active else {
            return
        }

        if isPressed {
            // SPACEBAR PRESSED
            gameState.isButtonPressed = true
            // SoundManager.shared.playButtonPressSound() // Disabled

            if gameState.gamePhase == .active {
                // Start pump and timing
                gameState.buttonPressStartTime = Date()
                bluetoothManager.startAirPump()
                print("🚀 Pump ON")
                logToFile("🚀 Pump ON")
            }
        } else {
            // SPACEBAR RELEASED - but verify it's actually released!
            // Check if spacebar is physically still down (CGEvent check)
            let spacebarStillDown = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(49))
            
            if spacebarStillDown {
                // False release event (happens when clicking buttons while holding spacebar)
                print("⚠️ Ignoring false keyUp - spacebar still physically held")
                logToFile("⚠️ Ignoring false keyUp - spacebar still physically held")
                return
            }
            
            gameState.isButtonPressed = false
            
            if gameState.gamePhase == .active {
                // DON'T stop pump here - completeCycle() will handle it
                // This prevents rapid Air ON/OFF cycling which triggers firmware heater toggle
                print("🎹 Spacebar released - pump stays on until cycle ends")
                logToFile("🎹 Spacebar released - pump stays on until cycle ends")
                
                // Calculate points and end cycle (completeCycle stops the pump)
                let drawTime = gameState.buttonPressStartTime != nil ?
                    Date().timeIntervalSince(gameState.buttonPressStartTime!) : 0
                gameState.buttonPressStartTime = nil

                if gameState.timeRemaining > 0 {
                    // Early release
                    print("💥 Early release - \(String(format: "%.1f", drawTime))s held")
                    logToFile("💥 Early release - \(String(format: "%.1f", drawTime))s held")
                    gameState.completeCycle(success: false, drawTime: drawTime)
                }
            }
        }
    }
}