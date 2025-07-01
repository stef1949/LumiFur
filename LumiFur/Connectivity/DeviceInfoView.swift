//
//  DeviceInfoView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/7/25.
//
import SwiftUI

struct DeviceInfoView: View {
    // Observe the same view-model you use in UnifiedConnectionView
    @ObservedObject var accessoryViewModel: AccessoryViewModel

    var body: some View {
        VStack(alignment: .trailing) {
            if let info = accessoryViewModel.deviceInfo {
                // Info is available → animate this block in
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Model: \(info.model)")
                    Text("Firmware: \(info.fw)")
                    Text("Commit: \(info.commit)")
                    Text("Branch: \(info.branch)")
                    Text("Date: \(info.build)")
                    Text("Compatible App: \(info.compat)+")
                    Text("ID: \(info.id)")
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            } else {
                // Still connecting → simple fade
                Text("Connecting...")
                    .foregroundColor(.gray)
                    .transition(.opacity)
            }
        }
        .frame(width: 200)
        .lineLimit(1)
        .font(.footnote)
        .foregroundStyle(.secondary)
        // Animate whenever deviceInfo changes
                .animation(
                    .easeInOut(duration: 0.3),
                    value: accessoryViewModel.deviceInfo != nil
                )
    }
}
