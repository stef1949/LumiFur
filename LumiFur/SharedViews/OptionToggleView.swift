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
        BouncingButton(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isOn.toggle()
            }
        }) {
            Text(title)
                .dynamicTypeSize(.medium)
                .fontWeight(.medium)
                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) // Combined padding
            //.blendMode(.destinationOut)
                .background(backgroundFillView)
                .clipShape(Capsule())
        }
        .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    private var backgroundFillView: some View { // Renamed
        if isOn {
            activeBackground
                .opacity(0.7)
        } else {
            Color(UIColor.systemGray5)
        }
    }
    
    @ViewBuilder
    private var activeBackground: some View {
        switch optionType {
        case .autoBrightness:
            LinearGradient(
                gradient: Gradient(colors: [.red, .orange, .yellow]),
                startPoint: .bottom,
                endPoint: .top
            )
        case .auroraMode:
            AngularGradient(
                gradient: Gradient(colors: [.pink, .purple, .blue, .green, .pink]),
                center: .center
            )
        case .sleepMode:
            LinearGradient(
                gradient: Gradient(colors: [.clear, .blue]),
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        default: // .accelerometer, .customMessage
            Color.green
        }
    }
}

