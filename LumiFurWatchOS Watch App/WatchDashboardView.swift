import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var model: WatchConnectivityManager

    var body: some View {
        List {
            Section {
                SessionSummaryRow()
                ControllerSummaryRow()
            }

            Section {
                controllerAction
            }

            Section("Explore") {
                ForEach(WatchDestination.allCases) { destination in
                    NavigationLink(value: destination) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(destination.title)
                                Text(destination.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: destination.systemImage)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("LumiFur")
        .task {
            model.refresh()
        }
    }

    @ViewBuilder
    private var controllerAction: some View {
        if model.controllerState.isInProgress {
            HStack {
                ProgressView()
                Text(model.controllerState.rawValue)
            }
        } else if model.controllerState.isConnected {
            Button(role: .destructive) {
                model.disconnectController()
            } label: {
                Label("Disconnect Controller", systemImage: "bolt.slash.fill")
            }
            .disabled(!model.sessionStatus.isReachable || model.isCommandInFlight)
        } else {
            Button {
                model.connectController()
            } label: {
                Label("Connect Controller", systemImage: "bolt.horizontal.circle.fill")
            }
            .disabled(!model.canRequestConnection)
        }
    }
}

private struct SessionSummaryRow: View {
    @EnvironmentObject private var model: WatchConnectivityManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.sessionStatus.systemImage)
                .foregroundStyle(model.sessionStatus.tint)
                .symbolEffect(.rotate, isActive: model.sessionStatus == .activating)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.sessionStatus.title)
                    .font(.headline)
                if let companionDeviceName = model.companionDeviceName {
                    Text(companionDeviceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ControllerSummaryRow: View {
    @EnvironmentObject private var model: WatchConnectivityManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.controllerState.symbolName)
                .foregroundStyle(model.controllerState.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.controllerName ?? "LumiFur Controller")
                    .font(.headline)
                Text(model.controllerState.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if let temperatureC = model.temperatureC {
                Text(temperatureC, format: .number.precision(.fractionLength(1)))
                    .font(.title3.monospacedDigit())
                    .overlay(alignment: .topTrailing) {
                        Text("°C")
                            .font(.caption2)
                            .offset(x: 12)
                    }
                    .padding(.trailing, 10)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
