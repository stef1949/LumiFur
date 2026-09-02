//
//  ConnectionState.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/3/25.
//

import SwiftUI

// This extension makes ConnectionState the single source of truth for its own UI representation.
extension ConnectionState {
    var statecolor: Color {
        switch self {
        case .connected: return .green
        case .connecting, .scanning: return .orange
        case .reconnecting: return .yellow
        case .failed: return .red
        case .disconnected, .bluetoothOff: return .gray
        case .unknown: return .purple
        }
    }

    var imageName: String {
        switch self {
        case .connected:
            return "bluetooth.fill"
        case .connecting, .scanning, .reconnecting:
            return "antenna.radiowaves.left.and.right"
        case .disconnected, .bluetoothOff, .unknown:
           return "wifi.slash"
        case .failed:
           return "wifi.exclamationmark"
        }
    }

    var isAnimated: Bool {
        switch self {
        case .connecting, .scanning, .reconnecting:
            return true
        default:
            return false
        }
    }
}

struct ConnectionFeedbackView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label {
                Text(message)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 8)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .accessibilityHint("Removes this message")
        }
        .font(.callout)
    }
}
