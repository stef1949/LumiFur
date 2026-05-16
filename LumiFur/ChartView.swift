import Charts
import Combine
import SwiftUI

struct ChartView: View, Equatable {
    @Environment(\.scenePhase) private var scenePhase

    @Binding var isExpanded: Bool
    let seedData: [TemperatureData]
    let temperaturePublisher: AnyPublisher<[TemperatureData], Never>
    @Binding var selectedUnits: TempUnit

    let connected: Bool

    // private let bleModel: AccessoryViewModel

    private var displayUnit: TempUnit { selectedUnits }

    private func toDisplayUnit(_ celsius: Double) -> Double {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: displayUnit.unit)
            .value
    }

    static func == (lhs: ChartView, rhs: ChartView) -> Bool {
        lhs.isExpanded == rhs.isExpanded &&
        lhs.connected == rhs.connected &&
        lhs._selectedUnits.wrappedValue == rhs._selectedUnits.wrappedValue &&
        lhs.seedData.count == rhs.seedData.count &&
        lhs.seedData.last == rhs.seedData.last
    }

    // MARK: - State

    @State private var dataSubscription: AnyCancellable?
    @State private var samples: [TemperatureData] = []
    @State private var yAxisDomain: ClosedRange<Double> = 20...35
    @State private var domainEnd: Date = Date()

    // MARK: - Animation State

    @State private var chartPlotSize: CGSize = .zero
    @State private var animationEndFraction: CGFloat = 0.0

    // MARK: - Time window

    private let windowSeconds: TimeInterval = 3 * 60
    private let maxPoints: Int = 100

    private var xDomain: ClosedRange<Date> {
        domainEnd.addingTimeInterval(-windowSeconds)...domainEnd
    }

    var body: some View {
        let _ = IdleCPUDiagnostics.shared.recordViewBody("ChartView")
        Group {
            if connected {
                VStack(spacing: 8) {
                    header

                    if isExpanded {
                        styledChart {
                            ForEach(samples, id: \.id) { point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Temp", toDisplayUnit(point.temperature))
                                )
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding()
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: refreshActivityState)
        .onDisappear(perform: stopSubscription)
        .onChange(of: connected) { _, _ in
            refreshActivityState()
        }
        .onChange(of: isExpanded) { _, _ in
            refreshActivityState()
        }
        .onChange(of: scenePhase) { _, _ in
            refreshActivityState()
        }
        .onChange(of: selectedUnits) { _, _ in
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

    private func refreshActivityState() {
        if connected && isExpanded && scenePhase == .active {
            startSubscription()
        } else {
            stopSubscription()
        }
    }

    private func animateRevealTick() {
        animationEndFraction = 0.98
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.35)) {
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
                            .onChange(of: geometry.size) { _, newSize in
                                chartPlotSize = newSize
                            }
                    }
                }
            }
            .mask {
                Rectangle()
                    .padding(.trailing, (1 - animationEndFraction) * chartPlotSize.width)
            }
    }

    // MARK: - Subscription

    private func startSubscription() {
        guard dataSubscription == nil else { return }

        animationEndFraction = 0

        let initial = processData(from: seedData)
        samples = initial
        domainEnd = initial.last?.timestamp ?? Date()
        updateYAxisDomain(with: initial)

        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.35)) {
                animationEndFraction = 1
            }
        }

        dataSubscription = temperaturePublisher
            .sink { newSamples in
                IdleCPUDiagnostics.shared.recordTaskFire("chart.subscription")

                let processed = processData(from: newSamples)
                let lastIncoming = processed.last
                let lastCurrent = samples.last

                guard lastIncoming?.timestamp != lastCurrent?.timestamp ||
                        lastIncoming?.temperature != lastCurrent?.temperature else {
                    return
                }

                withAnimation(.linear(duration: 0.25)) {
                    samples = processed
                    domainEnd = processed.last?.timestamp ?? Date()
                    updateYAxisDomain(with: processed)
                }
                animateRevealTick()
            }
    }

    private func stopSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil
        animationEndFraction = 0
        samples = []
        domainEnd = Date()
        updateYAxisDomain(with: [])
    }

    // MARK: - Data Processing

    private func processData(from allData: [TemperatureData]) -> [TemperatureData] {
        let referenceDate = allData.last?.timestamp ?? Date()
        let cutoff = referenceDate.addingTimeInterval(-windowSeconds)
        let recent = allData.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return [] }

        let strideBy = max(1, recent.count / maxPoints)
        var downsampled: [TemperatureData] = []
        downsampled.reserveCapacity(min(maxPoints, recent.count))

        for (index, element) in recent.enumerated() where index.isMultiple(of: strideBy) {
            downsampled.append(element)
        }

        if downsampled.last?.timestamp != recent.last?.timestamp, let last = recent.last {
            downsampled.append(last)
        }

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

        let minRange = 8.0
        let baseRange = max(maxT - minT, minRange)
        let padding = baseRange * 0.25
        let mid = (maxT + minT) / 2
        let halfRange = (baseRange / 2) + padding

        yAxisDomain = (mid - halfRange)...(mid + halfRange)
    }
}
