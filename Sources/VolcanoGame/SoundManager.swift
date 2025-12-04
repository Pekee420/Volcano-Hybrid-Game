//
//  SoundManager.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import AppKit
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var speechSynthesizer = NSSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var consecutiveSuccesses = 0
    
    // Sound files folder - in the app's mp3 directory
    private var soundsFolder: URL? {
        // Try to find mp3 folder relative to executable
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let appFolder = executableURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mp3Folder = appFolder.appendingPathComponent("mp3")
        
        if FileManager.default.fileExists(atPath: mp3Folder.path) {
            return mp3Folder
        }
        
        // Fallback: try current working directory
        let cwdMp3 = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("mp3")
        if FileManager.default.fileExists(atPath: cwdMp3.path) {
            return cwdMp3
        }
        
        // Fallback: hardcoded path for development
        let devPath = URL(fileURLWithPath: "/Users/petermaksimenko/TradeRunner/VolcanoGame/mp3")
        if FileManager.default.fileExists(atPath: devPath.path) {
            return devPath
        }
        
        return nil
    }

    private init() {
        if let folder = soundsFolder {
            print("🔊 Sound files found at: \(folder.path)")
        } else {
            print("⚠️ No mp3 folder found!")
        }
    }

    // MARK: - Game Sounds
    
    /// Plays when a cycle is successfully completed - escalating based on cycle length!
    func playSuccessSound(cycleDuration: TimeInterval = 5) {
        consecutiveSuccesses += 1
        
        // Check for 3 hits in a row over 10 seconds - special sound!
        if consecutiveSuccesses >= 3 && cycleDuration >= 10 {
            if playSound("three10+hitsinrow") {
                return
            }
        }
        
        // Pick sound based on cycle duration (check highest first)
        if cycleDuration >= 30 {
            _ = playSound("30+")
        } else if cycleDuration >= 21 {
            _ = playSound("21+")
        } else if cycleDuration >= 20 {
            _ = playSound("20+")
        } else if cycleDuration >= 15 {
            _ = playSound("intense15+")
        } else if cycleDuration >= 10 {
            _ = playSound("10+")
        } else if cycleDuration >= 4 {
            _ = playSound("4+")
        } else {
            // Very short cycle, use 4+ as fallback
            _ = playSound("4+")
        }
    }

    /// Plays when player releases early - mocking sound based on how long they held
    func playFailureSound(drawTime: TimeInterval = 0) {
        consecutiveSuccesses = 0 // Reset streak
        
        if drawTime == 0 {
            // Never pressed button
            _ = playSound("failnobuttonpress")
        } else if drawTime > 12 {
            // Almost made it! Held for more than 12 sec
            _ = playSound("failaftermorethan12")
        } else if drawTime >= 10 {
            // Held for 10+ sec but failed
            _ = playSound("failafterlessthan10")
        } else if drawTime >= 5 {
            // Held for 5-10 sec
            _ = playSound("failafterlessthan10")
        } else if drawTime >= 2 {
            // Held for 2-5 sec
            _ = playSound("failafterlessthan5")
        } else {
            // Released very quickly (less than 2 sec)
            _ = playSound("failafterlessthan2sec")
        }
    }

    func playButtonPressSound() {
        // Silent - no annoying click spam
    }

    /// Plays during countdown before hit
    func playCountdownSound() {
        // No countdown sound for now (thomas-the-weed-engine removed)
    }
    
    /// Plays when winner is shown - "Smoke Weed Every Day!"
    func playWinnerSound() {
        _ = playSound("smoke-weed-everyday-sound-effect")
    }
    
    /// Plays when someone gets eliminated
    func playEliminationSound() {
        _ = playSound("whensomeonehastoleaveround")
    }
    
    /// Plays at game start
    func playGameStartSound() {
        // No game start sound for now
    }
    
    // MARK: - Sound Playing Helpers
    
    private func playSound(_ name: String) -> Bool {
        guard let folder = soundsFolder else {
            print("❌ No sounds folder!")
            return false
        }
        
        let url = folder.appendingPathComponent("\(name).mp3")
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                audioPlayer?.stop()
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                print("🔊 Playing: \(name).mp3")
                return true
            } catch {
                print("❌ Error playing \(name): \(error)")
            }
        } else {
            print("⚠️ Sound not found: \(url.path)")
        }
        return false
    }
    
    private func speak(_ text: String, rate: Float = 0.5) {
        speechSynthesizer.rate = rate
        speechSynthesizer.startSpeaking(text)
    }
    
    /// Stop any currently playing sound
    func stopAllSounds() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking()
    }
    
    /// Reset consecutive success counter
    func resetStreak() {
        consecutiveSuccesses = 0
    }
}