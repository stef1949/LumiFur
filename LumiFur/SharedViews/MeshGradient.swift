//
//  Untitled.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//
import SwiftUI

struct meshGradient: View {
    @State private var isAnimating = false
    var body: some View {
            if #available(iOS 18.0, *) {
                MeshGradient(width: 3, height: 3, points: [
                    [0.0, 0.0], [0.5, 0], [1.0, 0.0],
                    [0.0, 0.5], [isAnimating ? 0.1 : 0.9, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ], colors: [
                    // Red with reduced saturation
                    Color(hue: 0.0, saturation: 1, brightness: 1.0),
                    // Purple with reduced saturation
                    Color(hue: 0.75, saturation: 1, brightness: 1.0),
                    // Indigo with reduced saturation (brightness adjusted slightly)
                    Color(hue: 0.66, saturation: 1, brightness: 0.9),
                    // Orange with reduced saturation
                    Color(hue: 0.08, saturation: 1, brightness: 1.0),
                    // White when animating, otherwise a less saturated brown
                    isAnimating ? .white : Color(hue: 0.05, saturation: 1, brightness: 0.6),
                    // Blue with reduced saturation
                    Color(hue: 0.6, saturation: 1, brightness: 1.0),
                    // Yellow with reduced saturation
                    Color(hue: 0.16, saturation: 1, brightness: 1.0),
                    // Green with reduced saturation
                    Color(hue: 0.33, saturation: 1, brightness: 1.0),
                    // Mint with reduced saturation (using a mid saturation value)
                    Color(hue: 0.5, saturation: 1, brightness: 1.0)
                ],
                             smoothsColors: true,
                             colorSpace: .perceptual
                )
                //.opacity(0.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                        isAnimating.toggle()
                    }
                }
            } else {
                // Fallback on earlier versions
            }
    }
}
