//
//  AboutSectionView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/4/25.
//
import SwiftUI

// This is now its own reusable, previewable, and highly optimized component.
struct AboutSectionView: View {
    // It explicitly declares the data it needs.
    let appVersion: String
    let firmwareVersion: String
    let isConnected: Bool

    var body: some View {
        Section("About") {
            HStack {
                Text("App Version")
                Spacer()
                Text(appVersion).foregroundColor(.secondary)
            }
            
            HStack {
                Text("LumiFur Controller Firmware")
                Spacer()
                Text(firmwareVersion)
                    .foregroundColor(.secondary)
            }
            // The view's dependency on `isConnected` is now explicit.
            .opacity(isConnected ? 1 : 0.5)
        }
    }
}
