//
//  SettingsView.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var gameState: GameState
    @StateObject private var soundManager = SoundManager.shared
    @State private var volcanoBrightnessDouble: Double = Double(UserDefaults.standard.integer(forKey: "volcanoBrightness") == 0 ? 100 : UserDefaults.standard.integer(forKey: "volcanoBrightness"))
    @Environment(\.dismiss) var dismiss
    
    private var volcanoBrightness: Int {
        Int(volcanoBrightnessDouble)
    }

    var body: some View {
        settingsContent
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
        #endif
            .onAppear {
                let saved = UserDefaults.standard.integer(forKey: "volcanoBrightness")
                if saved > 0 {
                    volcanoBrightnessDouble = Double(saved)
                } else if BluetoothManager.shared.currentBrightness > 0 {
                    volcanoBrightnessDouble = Double(BluetoothManager.shared.currentBrightness)
                }
            }
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 20) {
            Text("Game Settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            Form {
                Section(header: Text("Timing")) {
                    VStack(alignment: .leading) {
                        Text("Initial Cycle Duration: \(String(format: "%.1f", gameState.settings.initialCycleDuration))s")
                        Slider(value: $gameState.settings.initialCycleDuration, in: 3...15, step: 0.5)
                    }

                    VStack(alignment: .leading) {
                        Text("Cycle Increment: \(String(format: "%.1f", gameState.settings.cycleIncrement))s")
                        Slider(value: $gameState.settings.cycleIncrement, in: 0.5...5, step: 0.5)
                    }

                    VStack(alignment: .leading) {
                        Text("Pause Between Cycles: \(String(format: "%.1f", gameState.settings.pauseBetweenCycles))s")
                        Slider(value: $gameState.settings.pauseBetweenCycles, in: 1...10, step: 0.5)
                    }

                    VStack(alignment: .leading) {
                        Text("Preparation Time: \(String(format: "%.1f", gameState.settings.preparationTime))s")
                        Slider(value: $gameState.settings.preparationTime, in: 2...10, step: 0.5)
                    }
                }

                Section(header: Text("Scoring")) {
                    VStack(alignment: .leading) {
                        Text("Penalty Points: \(gameState.settings.penaltyPoints)")
                        Slider(value: intBinding(for: $gameState.settings.penaltyPoints), in: 5...50, step: 5)
                    }

                    VStack(alignment: .leading) {
                        Text("Completion Bonus: \(gameState.settings.completionBonus)")
                        Slider(value: intBinding(for: $gameState.settings.completionBonus), in: 10...100, step: 5)
                    }
                }

                Section(header: Text("Game Mode")) {
                    Toggle("Hardcore Mode", isOn: $gameState.settings.hardcoreMode)

                    if gameState.settings.hardcoreMode {
                        Text("Players are eliminated when they fail to complete a cycle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Sound")) {
                    Toggle("Mute All Sounds", isOn: $soundManager.isMuted)
                    
                    if !soundManager.isMuted {
                        VStack(alignment: .leading) {
                            Text("Volume: \(Int(soundManager.volume * 100))%")
                            Slider(value: $soundManager.volume, in: 0...1, step: 0.1)
                        }
                    }
                }
                
                Section(header: Text("Volcano Display")) {
                    VStack(alignment: .leading) {
                        Text("LED Brightness: \(volcanoBrightness)%")
                        Slider(value: $volcanoBrightnessDouble, in: 0...100, step: 10)
                            .onChange(of: volcanoBrightnessDouble) { newValue in
                                BluetoothManager.shared.setBrightness(Int(newValue))
                            }
                    }
                    
                    if !BluetoothManager.shared.isConnected {
                        Text("Connect to Volcano to adjust brightness")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            Spacer()

            HStack {
                Button("Reset to Defaults") {
                    gameState.settings = GameSettings()
                    volcanoBrightnessDouble = 100
                }
                .foregroundColor(.red)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                #if os(macOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// Helper to create bindings for Int values in Sliders
func intBinding(for value: Binding<Int>) -> Binding<Double> {
    Binding<Double>(
        get: { Double(value.wrappedValue) },
        set: { value.wrappedValue = Int($0) }
    )
}
