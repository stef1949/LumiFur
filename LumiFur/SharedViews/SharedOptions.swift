//
//  SharedOptions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/8/25.
//
#if os(iOS)
import UIKit
#endif

#if os(watchOS)
import WatchKit
#endif


struct SharedOptions {
    // Array of SF Symbol names
    //static let protoActionOptions2: [String] = [ "", "🎨", "🏳️‍⚧️", "🙂", "😳", "😎", "☠️", "😈", "😵‍💫", "+", "UwU", "✨", "BSOD", "📀" ]
    //static let protoActionOptions: [String] = ["😊", "⚾", "💀", "💩", "✨", "💕"]
    
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

    static let protoActionOptions3: [ProtoAction] = [
        .symbol("apple.logo"),
        .symbol("paintpalette.fill"),
        .emoji("🏳️‍⚧️"),
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
        .symbol("thermometer.high"),
        .symbol("flame.fill"),
        .emoji("😲"),
        .emoji("🌀"),
        .emoji("꩜")
    ]
}
