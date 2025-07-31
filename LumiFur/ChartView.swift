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

    // MARK: - Body
    
    var body: some View {
        // The entire view is a VStack. All modifiers are applied to this container.
        VStack(spacing: 8) {
            // Header with an interactive title and a chevron to indicate expandability.
            HStack {
                Text("Temperature")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.up")
                    .rotationEffect(.degrees(isExpanded ? 0 : 180)) // Corrected rotation
            }
            .contentShape(Rectangle()) // Makes the entire HStack tappable
            .onTapGesture {
                 isExpanded.toggle() // The parent's @State changes, triggering animation
            }

            // The chart is conditionally rendered only when `isExpanded` is true.
            if isExpanded {
                Chart(samples) { element in
                    LineMark(
                        x: .value("Time", element.timestamp),
                        y: .value("℃", element.temperature)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXScale(domain: Date().addingTimeInterval(-3 * 60) ... Date())
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute)) {
                        AxisValueLabel(format: .dateTime.minute().second(), centered: true)
                             .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks { axis in
                        AxisValueLabel {
                            if let temp = axis.as(Double.self) {
                                Text(String(format: "%.0f°C", temp))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                // A fixed height is given to the chart for a stable layout.
                .frame(height: 100)
                // A gentle transition for the chart appearing and disappearing.
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        // Using .onChange is the modern, correct way to react to state changes.
        .onChange(of: isExpanded) { _, isNowExpanded in
            if isNowExpanded {
                startSubscription()
            } else {
                stopSubscription()
            }
        }
        // These ensure the subscription is correctly handled when the view
        // appears (already expanded) or disappears from the screen entirely.
        .onAppear {
            if isExpanded {
                startSubscription()
            }
        }
        .onDisappear(perform: stopSubscription)
    }

    // MARK: - Optimization Logic

    /// **Optimization:** Subscribes to the viewModel's temperature data.
    /// This function is only called when the chart is expanded. It uses `throttle`
    /// to limit the rate of updates, preventing the UI from updating too frequently.
    private func startSubscription() {
        guard dataSubscription == nil else { return }
        print("✅ Starting Temperature data subscription.")

        dataSubscription = accessoryViewModel.temperatureChartPublisher
            // Throttle ensures we don't receive a flood of updates.
            .throttle(for: 0.5, scheduler: RunLoop.main, latest: true)
            .sink { newSamples in
                // Process and downsample the data for efficient rendering.
                self.samples = self.processData(from: newSamples)
            }
        
        // Immediately populate with existing data on expand
        self.samples = processData(from: accessoryViewModel.temperatureData)
    }

    /// **Optimization:** Cancels the subscription and clears the data.
    /// This is crucial for performance. It stops all data processing and frees memory
    /// when the chart is collapsed or no longer on screen.
    private func stopSubscription() {
        dataSubscription?.cancel()
        dataSubscription = nil
        samples = [] // Clear samples to free memory and ensure a clean state on next expand.
        print("🛑 Stopped Temperature data subscription.")
    }

    /// **Optimization:** Downsamples the data to a manageable size (~100 points).
    /// Rendering thousands of data points is inefficient. This function ensures the chart
    /// remains visually representative without overloading the rendering engine.
    private func processData(from allData: [TemperatureData]) -> [TemperatureData] {
        let cutoff = Date().addingTimeInterval(-3 * 60) // Only show last 3 minutes
        let recent = allData.filter { $0.timestamp >= cutoff }
        
        // If there are more than 100 points, take every Nth point.
        let strideBy = max(1, recent.count / 100)
        
        return recent.enumerated().compactMap { index, element in
            index.isMultiple(of: strideBy) ? element : nil
        }
    }
}