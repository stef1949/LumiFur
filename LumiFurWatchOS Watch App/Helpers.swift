//
//  Helpers.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//
import SwiftUI

    // Helper for status color (Optional)
     func statusColor(_ status: String) -> Color {
        switch status {
        case "Connected": return .green
        case "Connecting...", "Reconnecting...": return .yellow
        case "Disconnected", "Inactive", "Deactivated", "Not Supported", "Not Activated": return .red
        default: return .gray // Handle "Connected (Not Reachable)" or others
        }
    }
    
    // Helper to check connection state
     func isConnectedOrConnecting(_ status: String) -> Bool {
        return status == "Connected" || status.starts(with: "Connecting") || status.starts(with: "Connected (")
    }

