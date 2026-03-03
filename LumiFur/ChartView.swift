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
    @State private var yAxisDomain: ClosedRange<Double> = 20...35

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
    
    // Smooth scroll cadence (10 fps feels good)
    private let nowTick: TimeInterval = 5.0

    private func startNowTimer() {
        guard nowTimer == nil else { return }

        nowTimer = Timer.publish(every: nowTick, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Animate the x-domain shift
                withAnimation(.linear(duration: nowTick)) {
                    now = Date()
                }
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
                        .interpolationMethod(.catmullRom)
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
    private func animateRevealTick() {
        // start slightly hidden then reveal to the end
        animationEndFraction = 0.98
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 1.0)) {
                animationEndFraction = 1.0
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
            .animation(.linear(duration: 1.0), value: samples)
            .animation(.linear(duration: 1.0), value: yAxisDomain)
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
        /*
            .animation(nil, value: samples)
            .animation(nil, value: yAxisDomain)
            .animation(nil, value: now)
         */
    }

    // MARK: - Subscription
    private func startSubscription() {
        guard dataSubscription == nil else { return }
        animationEndFraction = 0.0

        // Prime the chart immediately from the current buffered data
        let initial = processData(from: accessoryViewModel.temperatureData)
        samples = initial
        updateYAxisDomain(with: initial)

        // `now` is maintained by the 1Hz timer while expanded
        // so we don't override it here.

        // Animate reveal after first layout
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 1.0)) {
                animationEndFraction = 1.0
            }
        }

        dataSubscription = accessoryViewModel.temperatureChartPublisher
            //.receive(on: RunLoop.main)
            .sink { newSamples in
                guard isExpanded else { return }

                let processed = processData(from: newSamples)

                let lastIncoming = processed.last
                let lastCurrent = samples.last

                guard lastIncoming?.timestamp != lastCurrent?.timestamp
                   || lastIncoming?.temperature != lastCurrent?.temperature
                else { return }

                withAnimation(.linear(duration: 0.25)) {
                    samples = processed
                    updateYAxisDomain(with: processed)
                }
                animateRevealTick()
            }
    }

    private func stopSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil

        animationEndFraction = 0.0
        samples = []
        updateYAxisDomain(with: [])
    }

    // MARK: - Data processing
    private func processData(from allData: [TemperatureData]) -> [TemperatureData] {
        let cutoff = now.addingTimeInterval(-windowSeconds) // use stable "now"
        let recent = allData.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return [] }

        let strideBy = max(1, recent.count / maxPoints)
        var downsampled: [TemperatureData] = []
        downsampled.reserveCapacity(min(maxPoints, recent.count))

        for (idx, element) in recent.enumerated() where idx.isMultiple(of: strideBy) {
            downsampled.append(element)
        }

        // Always include the newest point so the chart advances every update
        if downsampled.last?.timestamp != recent.last?.timestamp {
            downsampled.append(recent.last!)
        }

        // Optional safety cap (since we might add one extra)
        if downsampled.count > maxPoints {
            downsampled.removeFirst(downsampled.count - maxPoints)
        }

        return downsampled
    }

    private func updateYAxisDomain(with data: [TemperatureData]) {
        guard !data.isEmpty else {
            let midC = 25.0
            let mid = toDisplayUnit(midC)
            yAxisDomain = (mid - 6)...(mid + 6)
            return
        }

        let temps = data.map { toDisplayUnit($0.temperature) }
        guard let minT = temps.min(), let maxT = temps.max() else { return }

        let minRange = 8.0                 // prevents over-zoom
        let baseRange = max(maxT - minT, minRange)
        let padding = baseRange * 0.25     // visual breathing room
        let mid = (maxT + minT) / 2

        let halfRange = (baseRange / 2) + padding
        yAxisDomain = (mid - halfRange)...(mid + halfRange)
    }
}
