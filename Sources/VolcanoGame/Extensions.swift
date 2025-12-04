//
//  Extensions.swift
//  VolcanoGame
//
//  Created by AI Assistant on 2024.
//

import Foundation

// MARK: - Data Extension for Hex Debugging
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
