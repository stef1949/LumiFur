//
//  SharedOptions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/8/25.
//

struct SharedOptions {
    // Array of SF Symbol names
    //static let protoActionOptions2: [String] = [ "", "🎨", "🏳️‍⚧️", "🙂", "😳", "😎", "☠️", "😈", "😵‍💫", "+", "UwU", "✨", "BSOD", "📀" ]
    //static let protoActionOptions: [String] = ["😊", "⚾", "💀", "💩", "✨", "💕"]
    
    static let protoConfigOptions: [String] = ["Auto Brightness", "Accelerometer", "Sleep Mode", "Aurora Mode", "Custom Message"]
    
    enum ProtoAction {
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
        .symbol("thermometer.high")
    ]
}
