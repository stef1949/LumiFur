//
//  liveActivity.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - BLE Activity Attributes

struct BLEActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var connectionStatus: String
        var signalStrength: Int
    }
    
    // Static attribute: the device name remains constant during the live activity.
    var deviceName: String
}

// MARK: - BLE Live Activity View

struct BLELiveActivityView: View {
    let context: ActivityViewContext<BLEActivityAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            Text(context.attributes.deviceName)
                .font(.headline)
            Text(context.state.connectionStatus)
                .font(.title2)
            Text("Signal: \(context.state.signalStrength) dBm")
                .font(.caption)
        }
        .padding()
        .background(Color.white.opacity(0.9))
    }
}
