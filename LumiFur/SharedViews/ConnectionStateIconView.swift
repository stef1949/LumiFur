//
//  ConnectionStateIconView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/3/25.
//

import SwiftUI

/// A view that displays an icon representing a `ConnectionState`,
/// handling all animation and styling internally.
struct ConnectionStateIconView: View {
    let state: ConnectionState

    var body: some View {
        // The Group allows us to apply modifiers to the conditional content within.
        Group {
            if state.isAnimated {
                // View for animated states (.connecting, .scanning, etc.)
                Image(systemName: state.imageName)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeat(.continuous))
            } else {
                // View for static states (.connected, .disconnected, etc.)
                Image(systemName: state.imageName)
                    .symbolRenderingMode(state == .connected ? .multicolor : .monochrome)
                    .opacity(state == .connected ? 1.0 : 0.7)
            }
        }
        .foregroundStyle(state.statecolor) // Applies color to monochrome and animated symbols
        // Use a smooth symbol-to-symbol animation when the state changes.
        .contentTransition(.symbolEffect(.replace))
    }
}
