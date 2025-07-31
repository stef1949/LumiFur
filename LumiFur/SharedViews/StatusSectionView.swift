//
//  StatusSectionView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI

struct StatusSectionView: View {
    // MARK: - Properties
    let connectionState: ConnectionState
    let connectionStatus: String
    let signalStrength: Int
    let showSignalView: Bool

    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            if showSignalView {
                SignalStrengthView(rssi: signalStrength)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .padding(.leading, 5)
            }
            
            // Use the new, reusable icon view.
            // The .id() modifier is crucial for telling SwiftUI to animate the change.
            ConnectionStateIconView(state: connectionState)
                .id(connectionState)

            Text(connectionStatus)
                .font(.caption)
                // Get the color directly from the extension on ConnectionState.
                .foregroundStyle(connectionState.color)
                .id(connectionStatus)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        // The .animation modifier on the container animates all changes within it,
        // including the icon replacement and text transitions.
        .animation(.bouncy(duration: 0.4), value: connectionState)
        .padding(10)
        .glassEffect()
    }
}
