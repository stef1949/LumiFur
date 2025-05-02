//
//  OptionToggleView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//

import SwiftUI

enum OptionType {
    case autoBrightness, accelerometer, sleepMode, auroraMode, customMessage
}

struct OptionToggleView: View {
    let title: String
    @Binding var isOn: Bool
    let optionType: OptionType
    
    var body: some View {
        BouncingButton(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isOn.toggle()
            }
        }) {
            Text(title)
                .dynamicTypeSize(.medium)
                .fontWeight(.medium)
                .padding(8)
                .padding(.horizontal, 4)
                .clipShape(Capsule())
                //.blendMode(.destinationOut)
                .background(backgroundView)
                .clipShape(Capsule())
        }
        .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch optionType {
        case .autoBrightness:
            if isOn {
                LinearGradient(
                    gradient: Gradient(colors: [Color.red, Color.orange, Color.yellow]),
                    startPoint: .bottom,
                    endPoint: .top
                ).opacity(0.7)
            } else {
                Color(UIColor.systemGray5)
            }
        case .auroraMode:
            if isOn {
                AngularGradient(
                    gradient: Gradient(colors: [Color.pink, Color.purple, Color.blue, Color.green, Color.pink]),
                    center: .center
                ).opacity(0.7)
            } else {
                Color(UIColor.systemGray5)
            }
        case .sleepMode:
            if isOn {
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.blue]),
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ).opacity(0.7)
            } else {
                Color(UIColor.systemGray5)
            }
        default:
            if isOn {
                Color.green.opacity(0.7)
            } else {
                Color(UIColor.systemGray5)
            }
        }
    }
}
