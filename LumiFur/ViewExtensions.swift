//
//  ViewExtensions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 06/09/2024.
//
import SwiftUI

extension View {
    // Define a reusable function to display and animate the "Protogen" image
    func animatedProtogenImage(yOffset: Binding<CGFloat>, animationDirection: Bool, animationDuration: Double) -> some View {
        Image("Protogen")
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
