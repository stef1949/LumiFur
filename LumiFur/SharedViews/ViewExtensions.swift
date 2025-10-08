//
//  ViewExtensions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import SwiftUI

/*
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
*/


// 2) Equatable, value‑only button so SwiftUI can skip it when inputs don’t change
struct BouncingButton<Label: View>: View{
    let action: () -> Void
    let label: Label

    @State private var isPressed = false
    private let spring = Animation.spring(response: 0.3, dampingFraction: 0.5)

    init(action: @escaping () -> Void,
             @ViewBuilder label: @escaping () -> Label)
        {
            self.action = action
            self.label = label()
        }

    var body: some View {
        Button {
            // animate press
            withAnimation(spring) { isPressed = true }
            action()
            // animate release
            DispatchQueue.main.asyncAfter(deadline: .now()+0.15) {
                withAnimation(spring) { isPressed = false }
            }
        } label: {
            label
                .scaleEffect(isPressed ? 0.8 : 1.0)
                .animation(spring, value: isPressed)
        }
        //.buttonStyle(.glass)
        .glassEffect(.regular.interactive())
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
