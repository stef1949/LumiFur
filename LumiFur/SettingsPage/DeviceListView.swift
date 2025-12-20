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
        if viewModel.isConnected, let device = viewModel.connectedDevice {
            ConnectedDeviceView(peripheral: device)
                .connectionCard()
                .padding(.horizontal)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.discoveredDevices) { device in
                    DeviceRowButton(
                        leadingIcon: "antenna.radiowaves.left.and.right",
                        title: device.name,
                        rssi: device.rssi,
                        isConnecting: viewModel.isConnecting && viewModel.connectingPeripheral?.id == device.id,
                        isDisabled: viewModel.isConnecting,
                        action: { viewModel.connect(to: device) }
                    )
                }

                if !viewModel.previouslyConnectedDevices.isEmpty {
                    Text("Previously Connected")
                        .font(.headline)
                        .padding(.top, 6)

                    ForEach(viewModel.previouslyConnectedDevices) { storedDevice in
                        DeviceRowButton(
                            leadingIcon: "clock.arrow.circlepath",
                            title: storedDevice.name,
                            rssi: nil,
                            isConnecting: viewModel.isConnecting &&
                                         viewModel.connectingPeripheral?.id.uuidString == storedDevice.id,
                            isDisabled: viewModel.isConnecting,
                            action: { viewModel.connectToStoredPeripheral(storedDevice) }
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
