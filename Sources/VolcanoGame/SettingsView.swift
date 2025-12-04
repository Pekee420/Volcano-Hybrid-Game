//
//  SettingsView.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
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
                        .toggleStyle(.switch)

                    if gameState.settings.hardcoreMode {
                        Text("Players are eliminated when they fail to complete a cycle")
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
                }
                .foregroundColor(.red)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
    }
}

// Helper to create bindings for Int values in Sliders
func intBinding(for value: Binding<Int>) -> Binding<Double> {
    Binding<Double>(
        get: { Double(value.wrappedValue) },
        set: { value.wrappedValue = Int($0) }
    )
}