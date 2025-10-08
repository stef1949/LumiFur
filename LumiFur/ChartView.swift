//
//  ChartView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/19/25.
//


import Charts
import Combine
import SwiftUI

/// A view that displays a chart of temperature data over time.
///
/// This view is optimized to only subscribe to and process data from the `AccessoryViewModel`
/// when it is expanded. This conserves battery and CPU by avoiding unnecessary work when the
/// chart is not visible.
struct ChartView: View {
    /// A binding to control whether the chart is in its expanded or collapsed state.
    /// The parent view controls this state.
    @Binding var isExpanded: Bool
    
    /// The source of truth for connection and sensor data. Passed as an `@ObservedObject`
    /// because this view's lifecycle is managed by its parent.
    @ObservedObject var accessoryViewModel: AccessoryViewModel
    
    // MARK: - State
    
    /// Stores the active data subscription. Kept as state to manage its lifecycle.
    @State private var dataSubscription: AnyCancellable?
    
    /// A downsampled and recent collection of temperature data points for rendering.
    /// Keeping this in `@State` ensures the view updates when the data changes.
    @State private var samples: [TemperatureData] = []
    
    /// OPTIMIZATION: The Y-axis domain is stored in `@State`. This prevents it from being
    /// recalculated on every view update, which is inefficient. It's now only calculated
    /// when new data arrives.
    @State private var yAxisDomain: ClosedRange<Double> = 20...30
    
    // MARK: - Animation State
    
    /// The size of the chart's plot area, captured using a GeometryReader.
    @State private var chartPlotSize: CGSize = .zero
    
    /// The completion fraction of the animation, from 0.0 (hidden) to 1.0 (fully visible).
    @State private var animationEndFraction: CGFloat = 0.0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
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
            
            if isExpanded {
                // CORRECTED: Call the styledChart function with a trailing closure
                // that provides the chart's content (the marks).
                styledChart {
                    // Use ForEach to create marks from the dynamic samples array.
                    // Note: Your TemperatureData model must conform to Identifiable.
                    ForEach(samples) { element in
                        LineMark(
                            x: .value("Time", element.timestamp),
                            y: .value("℃", element.temperature)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .transition(.opacity) // Use a simple fade for the container
            }
        }
        //.scrollClipDisabled()
        //.backgroundStyle(.clear)
        .padding()
        .onChange(of: isExpanded) { _, isNowExpanded in
            if isNowExpanded {
                startSubscription()
            } else {
                stopSubscription()
            }
        }
        .onAppear {
            if isExpanded {
                startSubscription()
            }
        }
        .onDisappear(perform: stopSubscription)
    }
    
    
    // MARK: - Chart View Builder
    
    /// A helper function to build and style the chart.
    /// It now correctly accepts a closure that returns ChartContent.
    private func styledChart<Content: ChartContent>(@ChartContentBuilder content: () -> Content) -> some View {
        // CORRECTED: Create the Chart here and apply modifiers to it.
        Chart {
            content() // Render the marks provided by the closure.
        }
        .frame(height: 100)
        .chartXScale(domain: Date().addingTimeInterval(-3 * 60) ... Date())
        .chartYScale(domain: yAxisDomain)
        .chartYAxis {
            AxisMarks(preset: .automatic, position: .leading) { axis in
                //AxisGridLine()
                AxisValueLabel {
                    if let temp = axis.as(Double.self) {
                        Text(String(format: "%.0f°C", temp))
                            .font(.caption2)
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
        // Apply animation modifiers
        .chartPlotStyle { plotArea in
            plotArea.overlay {
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        self.chartPlotSize = geometry.size
                    }
                }
            }
        }
        .mask {
            Rectangle()
                .padding(.trailing, (1 - animationEndFraction) * chartPlotSize.width)
        }
    }
    
    
    // MARK: - Data and Subscription Logic
    
    /// Subscribes to the viewModel's temperature data.
    private func startSubscription() {
        guard dataSubscription == nil else { return }
        print("✅ Starting Temperature data subscription.")
        
        let initialData = processData(from: accessoryViewModel.temperatureData)
        self.samples = initialData
        updateYAxisDomain(with: initialData)
        
        // Use DispatchQueue to ensure the view has been rendered before animating.
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.5)) {
                self.animationEndFraction = 1.0
            }
        }
        
        dataSubscription = accessoryViewModel.temperatureChartPublisher
        // Throttle is re-enabled for better performance.
        //.throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { newSamples in
                let processed = self.processData(from: newSamples)
                self.samples = processed
                self.updateYAxisDomain(with: processed)
            }
    }
    
    /// Cancels the subscription to stop data processing.
    private func stopSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil
        // Reset the animation state for the next time it opens.
        animationEndFraction = 0.0
        // Clear samples so the view is empty on collapse, ready for re-animation.
        samples = []
        print("🛑 Stopped Temperature data subscription.")
    }
    
    /// Downsamples data for rendering efficiency.
    private func processData(from allData: [TemperatureData]) -> [TemperatureData] {
        let cutoff = Date().addingTimeInterval(-3 * 60) // Last 3 minutes
        let recent = allData.filter { $0.timestamp >= cutoff }
        
        let strideBy = max(1, recent.count / 100)
        return recent.enumerated().compactMap { index, element in
            index.isMultiple(of: strideBy) ? element : nil
        }
    }
    
    /// Calculates and updates the Y-axis domain based on the current samples.
    private func updateYAxisDomain(with data: [TemperatureData]) {
        if !data.isEmpty {
            let temps = data.map(\.temperature)
            let minTemp = temps.min() ?? 15
            let maxTemp = temps.max() ?? 25
            self.yAxisDomain = (minTemp - 5)...(maxTemp + 5)
        }
    }
}
