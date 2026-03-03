//
//  StrokeControl.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 02/03/2026.
//

import SwiftUI

 struct StrobeControlsView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    
    @Binding var strobeEnabled: Bool
    @Binding var strobeColor: Color
    @Binding var strobeCycleMs: UInt16
    
    var body: some View {
        VStack {
            Section("Strobe") {

                Toggle("Enabled", isOn: $bleModel.strobeEnabled)
                    .onChange(of: bleModel.strobeEnabled) { _, enabled in
                        push(enabled: enabled)
                    }

                ColorPicker("Color", selection: $bleModel.strobeColor, supportsOpacity: false)
                    .disabled(!bleModel.strobeEnabled)
                    .onChange(of: bleModel.strobeColor) { _, newColor in
                        push(color: newColor)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cycle")
                        Spacer()
                        Text("\(bleModel.strobeCycleMs) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: Binding(
                            get: { Double(bleModel.strobeCycleMs) },
                            set: { bleModel.strobeCycleMs = UInt16($0) }
                        ),
                        in: 20...2000,
                        step: 1
                    )
                    .disabled(!bleModel.strobeEnabled)
                    .onChange(of: bleModel.strobeCycleMs) { _, newMs in
                        push(cycleMs: newMs)
                    }

                    Text("Lower = faster flashes. This maps to the controller’s cycle speed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func push(enabled: Bool? = nil, color: Color? = nil, cycleMs: UInt16? = nil) {
        bleModel.setStrobeSettings(
            enabled: enabled ?? bleModel.strobeEnabled,
            color: color ?? bleModel.strobeColor,
            cycleMs: cycleMs ?? bleModel.strobeCycleMs
        )
    }
}
