//
//  BouncingButtonStyle.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 5/16/25.
//

import SwiftUI

struct BouncingButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    // shrink when pressed
                    .scaleEffect(configuration.isPressed ? 0.92 : 1.0) // Scale down when pressed
                                .animation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0), value: configuration.isPressed)
                        }
        }
