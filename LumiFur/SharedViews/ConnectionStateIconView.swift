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
        Group {
            if state.isAnimated {
                imageView()
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeat(.continuous))
            } else {
                imageView()
                    .symbolRenderingMode(state == .connected ? .multicolor : .monochrome)
                    .opacity(state == .connected ? 1.0 : 0.7)
            }
        }
        .foregroundStyle(state.statecolor)
        .contentTransition(.symbolEffect(.replace))
    }

    @ViewBuilder
    private func imageView() -> some View {
        if usesSystemSymbol(state.imageName) {
            Image(systemName: state.imageName)
        } else {
            Image(state.imageName) // custom asset from asset catalog
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        }
    }

    /// Determines if a symbol name is an SF Symbol or a custom asset.
    private func usesSystemSymbol(_ name: String) -> Bool {
        switch name {
        case "antenna.radiowaves.left.and.right",
             "wifi.slash",
             "wifi.exclamationmark":
            return true
        default:
            return false // Treat "bluetooth.fill" as a custom symbol
        }
    }
}
