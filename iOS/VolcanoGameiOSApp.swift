//
//  VolcanoGameiOSApp.swift
//  VolcanoGame iOS
//

import SwiftUI

@main
struct VolcanoGameiOSApp: App {
    @StateObject private var gameState = GameState()
    
    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .environmentObject(gameState)
                .environmentObject(BluetoothManager.shared)
                .preferredColorScheme(.dark)
                .task {
                    // Delay Bluetooth initialization to prevent startup lag
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    await MainActor.run {
                        if !BluetoothManager.shared.isConnected {
                            BluetoothManager.shared.startScanning()
                        }
                    }
                }
        }
    }
}

