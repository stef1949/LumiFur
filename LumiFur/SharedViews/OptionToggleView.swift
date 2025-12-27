//
//  OptionToggleView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//

import SwiftUI


enum OptionType: Equatable {
    case autoBrightness, accelerometer, sleepMode, auroraMode, customMessage
}

// Cached shape styles to avoid rebuilding gradients on each render
private enum OptionToggleStyleCache {
    static let inactive = AnyShapeStyle(Color(UIColor.systemGray5))
    static let autoBrightness = AnyShapeStyle(
        LinearGradient(
            gradient: Gradient(colors: [.red, .orange, .yellow]),
            startPoint: .bottom,
            endPoint: .top
        )
    )
    static let auroraMode = AnyShapeStyle(
        AngularGradient(
            gradient: Gradient(colors: [.pink, .purple, .blue, .green, .pink]),
            center: .center
        )
    )
    static let sleepMode = AnyShapeStyle(
        LinearGradient(
            gradient: Gradient(colors: [.clear, .blue]),
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    )
    static let defaultActive = AnyShapeStyle(Color.green)
}

private extension OptionType {
    var activeShapeStyle: AnyShapeStyle {
        switch self {
        case .autoBrightness: return OptionToggleStyleCache.autoBrightness
        case .auroraMode:     return OptionToggleStyleCache.auroraMode
        case .sleepMode:      return OptionToggleStyleCache.sleepMode
        case .accelerometer, .customMessage:
            return OptionToggleStyleCache.defaultActive
        }
    }
}

struct OptionToggleView: View, Equatable {
    let title: String
    @Binding var isOn: Bool
    let optionType: OptionType
    
    // Equatable conformance only looks at the data,
    // not at any closures or view‐builder guts.
    static func ==(lhs: OptionToggleView, rhs: OptionToggleView) -> Bool {
        lhs.title       == rhs.title &&
        lhs.isOn        == rhs.isOn &&
        lhs.optionType  == rhs.optionType
    }
    
    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            Text(title)
                .dynamicTypeSize(.medium)
                .fontWeight(.medium)
                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .background(
            Capsule()
                .fill(OptionToggleStyleCache.inactive)
                .overlay(
                    Capsule()
                        .fill(optionType.activeShapeStyle)
                        .opacity(isOn ? 0.7 : 0.0)
                )
        )
        .foregroundStyle(.primary)
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

