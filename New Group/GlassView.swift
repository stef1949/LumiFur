//
//  GlassView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 5/12/25.
//


import SwiftUI

public struct GlassView: View {
    let cornerRadius: CGFloat
    let corners: UIRectCorner?
    let fill: Color
    let opacity: CGFloat
    let shadowRadius: CGFloat

    public init(cornerRadius: CGFloat, corners: UIRectCorner? = .allCorners, fill: Color = .white, opacity: CGFloat = 0.25, shadowRadius: CGFloat = 10.0) {
        self.cornerRadius = cornerRadius
        self.corners = corners
        self.fill = fill
        self.opacity = opacity
        self.shadowRadius = shadowRadius
    }

    public var body: some View {
        if corners != nil {
            Rectangle()
                .fill(fill)
                .opacity(opacity)
                .shadow(radius: shadowRadius)
                .cornerRadius(cornerRadius)
        } else {
            Rectangle()
                .fill(fill)
                .opacity(opacity)
                .shadow(radius: shadowRadius)
        }
    }
}

struct GlassView_Previews: PreviewProvider {
    static var previews: some View {
        GlassView(cornerRadius: 20.0)
    }
}

//MARK: - View Modifier

struct GlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let corners: UIRectCorner?
    let fill: Color
    let opacity: CGFloat
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                GlassView(cornerRadius: cornerRadius, corners: corners, fill: fill, opacity: opacity, shadowRadius: shadowRadius)
            }
    }
}

//MARK: - View Extension

extension View {
    public func glass(cornerRadius: CGFloat, corners: UIRectCorner? = .allCorners, fill: Color = .white, opacity: CGFloat = 0.25, shadowRadius: CGFloat = 10.0) -> some View {
        modifier(GlassModifier(cornerRadius: cornerRadius, corners: corners, fill: fill, opacity: opacity, shadowRadius: shadowRadius))
    }
}
