//
//  DeviceListView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/4/25.
//


import SwiftUI

// Replaces the `deviceList` computed property and eliminates `AnyView`.
struct DeviceListView: View {
    @ObservedObject var viewModel: AccessoryViewModel

    var body: some View {
        // @ViewBuilder allows us to return different view types
        // without needing to wrap them in AnyView. SwiftUI loves this.
        if viewModel.isConnected, let device = viewModel.connectedDevice {
            ConnectedDeviceView(peripheral: device) // Assuming this is a view you have
        } else {
            // This VStack now contains the logic for discovered/previous devices
            VStack(alignment: .leading, spacing: 16) {
                // Discovered Devices Section
                ForEach(viewModel.discoveredDevices) { device in
                    deviceRow(
                        name: device.name,
                        rssi: viewModel.signalStrength,
                        isConnecting: viewModel.connectingPeripheral?.id == device.id,
                        action: { viewModel.connect(to: device) }
                    )
                }

                // Previously Connected Devices Section
                if !viewModel.previouslyConnectedDevices.isEmpty {
                    Text("Previously Connected Devices").font(.headline).padding(.top)

                    ForEach(viewModel.previouslyConnectedDevices) { storedDevice in
                        deviceRow(
                            name: storedDevice.name,
                            rssi: nil,
                            isConnecting: viewModel.connectingPeripheral?.id.uuidString == storedDevice.id,
                            action: { viewModel.connectToStoredPeripheral(storedDevice) }
                        )
                    }
                }
            }
            .padding()
            .disabled(viewModel.isConnecting)
        }
    }
    
    // A private helper for this view's rows
    @ViewBuilder
    private func deviceRow(name: String, rssi: Int?, isConnecting: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer()
                if let rssiValue = rssi, !isConnecting {
                    SignalStrengthView(rssi: rssiValue)
                }
                if isConnecting {
                    ProgressView()
                }
            }
        }
    }
}