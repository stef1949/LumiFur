//
//  ConnectionState.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/28/25.
//

import SwiftUI

/// 1) A plain, raw-backed enum
enum ConnectionState: String {
    case disconnected   = "Disconnected"
    case scanning       = "Scanning for devices..."
    case connecting     = "Connecting..."
    case connected      = "Connected"
    case unknown
    
    // Display helpers live here, once & for all:
    var color: Color {
        switch self {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .gray
        case .scanning:     return .blue
        case .unknown:      return .red
        }
    }
    
    var imageName: String {
        switch self {
        case .connected:    return "bluetooth.fill"
        case .disconnected: return "bluetooth.slash.fill"
        case .connecting, .scanning:
            return "systemName: antenna.radiowaves.left.and.right"
        case .unknown:      return "systemName: questionmark"
        }
    }
}
