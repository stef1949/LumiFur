//
//  ViewExtensions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import SwiftUI

extension View {
    // Reusable function to display and animate the "Protogen" image
    func animatedProtogenImage(yOffset: Binding<CGFloat>, animationDirection: Bool, animationDuration: Double) -> some View {
        Image("Page23-2")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: yOffset.wrappedValue)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                    yOffset.wrappedValue = animationDirection ? -20 : 20
                }
            }
    }
}

struct BouncingButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    @State private var animate = false
    @State private var triggerHaptics = false
    var body: some View {
        Button(action: {
            // Trigger the bounce animation and haptics on tap
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                animate = true
                triggerHaptics = true // Start haptic feedback
            }
            // Return to normal scale after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    animate = false
                }
            }
            // Reset the haptics trigger so subsequent taps can trigger it again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                triggerHaptics = false
            }
            // Perform the button action
            action()
        })
        {
            label()
                .scaleEffect(animate ? 0.8 : 1.0)
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: triggerHaptics)
    }
}


public struct GradientToggleStyle: ToggleStyle {
    var gradient: LinearGradient

    public init(gradient: LinearGradient) {
        self.gradient = gradient
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    configuration.isOn.toggle()
                }
            }) {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(configuration.isOn ?
                              AnyShapeStyle(gradient) :
                              AnyShapeStyle(Color(UIColor.systemGray4)))
                        .frame(width: 51, height: 31)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .padding(2)
                        .shadow(radius: 1)
                }
                .animation(.easeInOut(duration: 0.3), value: configuration.isOn)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
