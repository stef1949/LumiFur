import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject private var model: WatchConnectivityManager
    @AppStorage("wristFlickEnabled") private var wristFlickEnabled = false

    var body: some View {
        List {
            Section("Controller") {
                Toggle("Auto Brightness", isOn: autoBrightness)
                
                Toggle("Max Maw Brightness", isOn: mouthBrightnessOverride)
                    .disabled(!model.configuration.autoBrightness)

                Toggle("Accelerometer", isOn: accelerometer)

                Toggle("Sleep Mode", isOn: sleepMode)

                Toggle("Aurora Mode", isOn: auroraMode)
            }
            .disabled(!model.canControlController)

            Section("Watch") {
                Toggle("Wrist Flick", isOn: $wristFlickEnabled)
                Text("Flick left or right while the Faces screen is open to change the active face.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !model.controllerState.isConnected {
                Section {
                    Label("Connect the controller to edit controller settings.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            model.refresh()
        }
    }

    private var autoBrightness: Binding<Bool> {
        Binding(
            get: { model.configuration.autoBrightness },
            set: { model.setAutoBrightness($0) }
        )
    }
    
    private var staticColor: Binding<Bool> {
        Binding(
            get: { model.configuration.staticColorEnabled },
            set: { model.setStaticColorEnabled($0) }
        )
    }
    
    private var mouthBrightnessOverride: Binding<Bool> {
        Binding(
            get: { model.configuration.mouthBrightnessOverrideEnabled },
            set: { model.setmouthBrightnessOverride($0) }
        )
    }

    private var accelerometer: Binding<Bool> {
        Binding(
            get: { model.configuration.accelerometerEnabled },
            set: { model.setAccelerometerEnabled($0) }
        )
    }

    private var sleepMode: Binding<Bool> {
        Binding(
            get: { model.configuration.sleepModeEnabled },
            set: { model.setSleepModeEnabled($0) }
        )
    }

    private var auroraMode: Binding<Bool> {
        Binding(
            get: { model.configuration.auroraModeEnabled },
            set: { model.setAuroraModeEnabled($0) }
        )
    }
}
