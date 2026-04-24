//
//  StrobeControlsView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 02/03/2026.
//

import SwiftUI

// MARK: - StrobeControlsView

/// Popover content for editing strobe settings.
struct StrobeControlsView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    let onDone: (() -> Void)?

    init(bleModel: AccessoryViewModel, onDone: (() -> Void)? = nil) {
        self.bleModel = bleModel
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Strobe")
                    .font(.headline)
                Spacer()
                if let onDone {
                    Button("Done", action: onDone)
                }
            }

            Toggle("Enabled", isOn: enabledBinding)

            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                .disabled(!bleModel.strobeEnabled)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Cycle")
                    Spacer()
                    Text("\(bleModel.strobeCycleMs) ms")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: cycleBinding,
                    in: 20...2000,
                    step: 1
                )
                .disabled(!bleModel.strobeEnabled)

                Text("Lower = faster flashes. This maps to the controller's cycle speed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { bleModel.strobeEnabled },
            set: { push(enabled: $0) }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { bleModel.strobeColor },
            set: { push(color: $0) }
        )
    }

    private var cycleBinding: Binding<Double> {
        Binding(
            get: { Double(bleModel.strobeCycleMs) },
            set: { push(cycleMs: UInt16($0.rounded())) }
        )
    }

    private func push(enabled: Bool? = nil, color: Color? = nil, cycleMs: UInt16? = nil) {
        bleModel.setStrobeSettings(
            enabled: enabled ?? bleModel.strobeEnabled,
            color: color ?? bleModel.strobeColor,
            cycleMs: cycleMs ?? bleModel.strobeCycleMs
        )
    }
}
