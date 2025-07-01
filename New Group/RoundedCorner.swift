//
//  RoundedCorner.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 5/12/25.
//

import SwiftUI

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


