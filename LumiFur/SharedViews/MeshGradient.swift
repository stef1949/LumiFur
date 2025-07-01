//
//  Untitled.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//
import SwiftUI

//@available(iOS 18.0, *)
struct MeshGradientView: View {
    /// Toggle from your view‐model
    //let enabled: Bool

    // drive 0→1 back and forth
    @State private var phase: Float = 0
    
    // one shared animation
    private let animation = Animation
        .easeInOut(duration: 5)
        .repeatForever(autoreverses: true)
    
    // 9 grid points; midpoint (index 4) will be animated
    private static let basePoints: [SIMD2<Float>] = [
        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
        SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
    ]
    
    // 9 colors; index 4 will be replaced each frame
    private static let baseColors: [Color] = [
        Color(hue: 0.00, saturation: 1, brightness: 1.0),
        Color(hue: 0.75, saturation: 1, brightness: 1.0),
        Color(hue: 0.66, saturation: 1, brightness: 0.9),
        Color(hue: 0.08, saturation: 1, brightness: 1.0),
        Color(hue: 0.05, saturation: 1, brightness: 0.6), // placeholder
        Color(hue: 0.60, saturation: 1, brightness: 1.0),
        Color(hue: 0.16, saturation: 1, brightness: 1.0),
        Color(hue: 0.33, saturation: 1, brightness: 1.0),
        Color(hue: 0.50, saturation: 1, brightness: 1.0)
    ]
    
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: animatedPoints(),
                    colors: animatedColors(),
                    smoothsColors: true,
                    colorSpace: .perceptual
                )
            } else {
                EmptyView()
            }
        }
    }
        // Move only the center point (index 4)
        private func animatedPoints() -> [SIMD2<Float>] {
        Self.basePoints.enumerated().map { idx, pt in
            // animate only the center point
            if idx == 4 {
                let x = 0.1 + (0.9 - 0.1) * phase
                return SIMD2<Float>(x, 0.5)
            }
            return pt
        }
    }
    
    // Blend the center color from brown→white
    private func animatedColors() -> [Color] {
        var cols = Self.baseColors
        // interpolate brown ↔ white
        let brown = Color(hue: 0.05, saturation: 1, brightness: 0.6)
        let w = Color.white
        // linear blend based on `phase`
        let dyn = Color(
            .sRGB,
            red:   w.components.red   * Double(phase) + brown.components.red   * (1 - Double(phase)),
            green: w.components.green * Double(phase) + brown.components.green * (1 - Double(phase)),
            blue:  w.components.blue  * Double(phase) + brown.components.blue  * (1 - Double(phase)),
            opacity: 1
        )
        cols[4] = dyn
        return cols
    }
}

// Helper to pull out sRGB components for blending
private extension Color {
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(UIKit)
        var r=CGFloat(), g=CGFloat(), b=CGFloat(), a=CGFloat()
        UIColor(self).getRed(&r, green:&g, blue:&b, alpha:&a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        return (1,1,1,1)
        #endif
    }
}
