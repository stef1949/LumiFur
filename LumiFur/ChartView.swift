import Charts
import Combine
import SwiftUI

struct ChartView: View {
    @Binding var isExpanded: Bool
    @ObservedObject var accessoryViewModel: AccessoryViewModel
    @Binding var selectedUnits: TempUnit   // ← binding from parent
    
    private var displayUnit: TempUnit { selectedUnits }
    
    private func toDisplayUnit(_ celsius: Double) -> Double {
            Measurement(value: celsius, unit: UnitTemperature.celsius)
                .converted(to: displayUnit.unit)
                .value
        }

    // MARK: - State
    @State private var dataSubscription: AnyCancellable?
    @State private var samples: [TemperatureData] = []
    @State private var yAxisDomain: ClosedRange<Double> = 20...30

    // MARK: - Animation State
    @State private var chartPlotSize: CGSize = .zero
    @State private var animationEndFraction: CGFloat = 0.0

    // MARK: - Time window
    private let windowSeconds: TimeInterval = 3 * 60
    private let maxPoints: Int = 100

    // Keep "now" stable for axis domain (updates once per second while expanded)
    @State private var now: Date = Date()
    private var xDomain: ClosedRange<Date> {
        (now.addingTimeInterval(-windowSeconds))...now
    }
    
    @State private var nowTimer: AnyCancellable?
    
    private func startNowTimer() {
        guard nowTimer == nil else { return }
        nowTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                now = Date()
            }
    }

    private func stopNowTimer() {
        nowTimer?.cancel()
        nowTimer = nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            header

            if isExpanded {
                styledChart {
                    ForEach(samples, id: \.id) { p in
                        LineMark(
                            x: .value("Time", p.timestamp),
                            y: .value("Temp", toDisplayUnit(p.temperature))
                        )
                        .interpolationMethod(.catmullRom(alpha: 0.0))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .transition(.opacity)
            }
        }
        .padding()
        .onChange(of: isExpanded) { _, isNowExpanded in
            if isNowExpanded {
                startNowTimer()
                startSubscription()
            } else {
                stopNowTimer()
                stopSubscription()
            }
        }
        .onAppear {
            if isExpanded {
                startNowTimer()
                startSubscription()
            }
        }
        .onDisappear {
            stopNowTimer()
            stopSubscription()
        }
        .onChange(of: selectedUnits) { _, _ in
            // Units changed: recompute domain (and samples if you want)
            updateYAxisDomain(with: samples)
        }
    }

    private var header: some View {
        HStack {
            Text("Temperature")
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.up")
                .rotationEffect(.degrees(isExpanded ? 0 : 180))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Chart Builder
    private func styledChart<Content: ChartContent>(
        @ChartContentBuilder content: () -> Content
    ) -> some View {
        Chart { content() }
            .frame(height: 100)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(preset: .automatic, position: .leading) { axisValue in
                    AxisValueLabel {
                        if let y = axisValue.as(Double.self) {
                            Text(
                                Measurement(value: y, unit: displayUnit.unit),
                                format: .measurement(width: .abbreviated)
                            )
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute)) {
                    AxisValueLabel(format: .dateTime.minute().second(), centered: true)
                        .font(.caption2)
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.overlay {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { chartPlotSize = geometry.size }
                            .onChange(of: geometry.size) { _, newSize in chartPlotSize = newSize }
                    }
                }
            }
            .mask {
                Rectangle()
                    .padding(.trailing, (1 - animationEndFraction) * chartPlotSize.width)
            }
            .animation(nil, value: samples)
            .animation(nil, value: yAxisDomain)
            .animation(nil, value: now)
    }

    // MARK: - Subscription
    private func startSubscription() {
        guard dataSubscription == nil else { return }

        // Prime the chart immediately
        let initial = processData(from: accessoryViewModel.temperatureData)
        samples = initial
        updateYAxisDomain(with: initial)
        now = Date()

        // Animate reveal after first layout
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.5)) {
                animationEndFraction = 1.0
            }
        }

        dataSubscription = accessoryViewModel.temperatureChartPublisher
            .receive(on: RunLoop.main)
            .sink { newSamples in
                // If we collapse while the publisher is still emitting
                guard isExpanded else { return }

                let processed = processData(from: newSamples)
                // Deduplicate: only update if there's a newer data point
                let latestIncoming = processed.last?.timestamp
                let latestCurrent = samples.last?.timestamp
                guard latestIncoming != nil && latestIncoming != latestCurrent else {
                    return
                }

                samples = processed
                updateYAxisDomain(with: processed)
                if let latest = latestIncoming {
                    now = latest
                }
            }
    }

    private func stopSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil

        animationEndFraction = 0.0
        samples = []
    }

    // MARK: - Data processing
    private func processData(from allData: [TemperatureData]) -> [TemperatureData] {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        let recent = allData.filter { $0.timestamp >= cutoff }

        let strideBy = max(1, recent.count / maxPoints)
        return recent.enumerated().compactMap { idx, element in
            idx.isMultiple(of: strideBy) ? element : nil
        }
    }

    private func updateYAxisDomain(with data: [TemperatureData]) {
        guard !data.isEmpty else {
            // reasonable default for the current unit
            let midC = 25.0
            let mid = toDisplayUnit(midC)
            yAxisDomain = (mid - 5)...(mid + 5)
            return
        }

        // IMPORTANT: compute in DISPLAY UNIT, because that's what we plot
        let temps = data.map { toDisplayUnit($0.temperature) }
        guard let minT = temps.min(), let maxT = temps.max() else { return }

        let padding = max(1.0, (maxT - minT) * 0.15) // adaptive padding
        yAxisDomain = (minT - padding)...(maxT + padding)
    }
}
