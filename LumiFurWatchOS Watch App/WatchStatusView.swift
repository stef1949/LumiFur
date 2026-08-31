import SwiftUI
import Charts

struct WatchStatusView: View {
    @EnvironmentObject private var model: WatchConnectivityManager

    private var chartSamples: [TemperatureSample] {
        let history = model.temperatureHistory
        guard history.count > 24 else { return history }

        let strideSize = max(1, history.count / 24)
        var samples = stride(from: 0, to: history.count, by: strideSize).map { history[$0] }
        if let latest = history.last, samples.last != latest {
            samples.append(latest)
        }
        return Array(samples.suffix(24))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                temperatureHeader
                controllerStatus

                if chartSamples.count >= 2 {
                    temperatureChart
                } else {
                    Label("Waiting for temperature history", systemImage: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let temperatureTimestamp = model.temperatureTimestamp {
                    Text("Updated \(temperatureTimestamp, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .navigationTitle("Status")
        .task {
            model.refresh()
        }
    }

    @ViewBuilder
    private var temperatureHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Temperature")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let temperatureC = model.temperatureC {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(temperatureC, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("°C")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                let temperatureF = (temperatureC * 9 / 5) + 32
                Text("\(temperatureF, format: .number.precision(.fractionLength(1)))°F")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.temperatureText)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var controllerStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: model.controllerState.symbolName)
                .foregroundStyle(model.controllerState.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.controllerName ?? "LumiFur Controller")
                    .font(.headline)
                Text(model.controllerState.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var temperatureChart: some View {
        Chart(chartSamples) { sample in
            AreaMark(
                x: .value("Time", sample.timestamp),
                y: .value("Temperature", sample.temperatureC)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.orange.opacity(0.5), .orange.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Temperature", sample.temperatureC)
            )
            .foregroundStyle(.orange)
            .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 78)
        .accessibilityLabel("Controller temperature history")
    }
}
