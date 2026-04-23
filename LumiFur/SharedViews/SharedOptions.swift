//
//  SharedOptions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/8/25.
//

import Foundation

#if os(iOS)
import UIKit
#endif

#if os(watchOS)
import WatchKit
#endif


// ✅ MOVE FaceItem HERE, to the top level of the file.
// Its name is now simply "FaceItem". This is the single source of truth.
struct FaceItem: Identifiable, Equatable {
    let id = UUID()
    let content: SharedOptions.ProtoAction // It can still refer to the enum inside SharedOptions
}


// SharedOptions now only contains the data and its specific enum/structs.
struct SharedOptions {
    struct ConfigOption: Identifiable {
        let id = UUID()
        let name: String
    }
    
    let configOptions: [ConfigOption] = SharedOptions.protoConfigOptions.map { ConfigOption(name: $0) }
    static let protoConfigOptions: [String] = ["Auto Brightness", "Accelerometer", "Sleep Mode", "Aurora Mode", "Custom Message"]
    
    enum ProtoAction: Equatable {
      case emoji(String)
      case symbol(String)
    }

    // ❌ FaceItem is no longer defined here.

    static let protoActionOptions: [ProtoAction] = [
        .symbol("apple.logo"),
        .symbol("paintpalette.fill"),
        .emoji("🏳️‍⚧️"),
        .emoji("🏳️‍🌈"),
        .emoji("🙂"),
        .emoji("😳"),
        .emoji("😎"),
        .emoji("☠️"),
        .emoji("😈"),
        .emoji("😵‍💫"),
        .emoji("+"),
        .emoji("UwU"),
        .emoji("✨"),
        .symbol("pc"),
        .symbol("opticaldisc.fill"),
        .symbol("flame.fill"),
        .symbol("water.waves"),
        .emoji("😲"),
        .emoji("🌀"),
        .emoji("꩜"),
        .symbol("bubble.and.pencil"),
        .emoji("🦖"),
        .symbol("laser.burst"),
        .emoji("rainbow fluid"),
        .symbol("rectangle.fill"),
        .symbol("arrow.trianglehead.2.clockwise.rotate.90"),
        .emoji("rainbow linear band"),
        .emoji("Alt Face"),
        .symbol("movieclapper.fill"),
    ]

    static let strobeActionSymbol = "laser.burst"
}

// MARK: - Helpers for testing and UI logic
extension SharedOptions.ProtoAction {
    /// Returns the underlying string for emoji or symbol
    var rawValue: String {
        switch self {
        case .emoji(let s):
            return s
        case .symbol(let s):
            return s
        }
    }
    
    /// Returns true if this action is an emoji, false if it's a symbol
    var isEmoji: Bool {
        switch self {
        case .emoji:
            return true
        case .symbol:
            return false
        }
    }

    /// Returns true for the face tile that exposes strobe controls in the dashboard.
    var isStrobeAction: Bool {
        !isEmoji && rawValue == SharedOptions.strobeActionSymbol
    }
}
