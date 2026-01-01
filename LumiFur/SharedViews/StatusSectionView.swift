//
//  StatusSectionView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI

struct StatusSectionView: View, Equatable {
    @State private var animatedLuxProgress: Double = 0.0
    @Namespace private var namespace
    
    // MARK: - Properties
    let connectionState: ConnectionState
    let connectionStatus: String
    let signalStrength: Int
    let showSignalView: Bool
    let luxValue: Double
    
    // Define your min/max lux values here or pass them in
    private static let minLux: Double = 1
    private static let maxLux: Double = 4097 // max value
    
    // Normalize to 0…1 on a log scale
    private var luxProgress: Double {
        // clamp to avoid log(0)
        let clamped = min(max(luxValue, Self.minLux), Self.maxLux)
        // compute logs (base-10 here, but natural log works too)
        let logMin   = log10(Self.minLux)
        let logMax   = log10(Self.maxLux)
        let logValue = log10(clamped)
        return (logValue - logMin) / (logMax - logMin)
    }

    static func == (lhs: StatusSectionView, rhs: StatusSectionView) -> Bool {
        lhs.connectionState == rhs.connectionState &&
        lhs.connectionStatus == rhs.connectionStatus &&
        lhs.signalStrength == rhs.signalStrength &&
        lhs.showSignalView == rhs.showSignalView &&
        lhs.luxValue == rhs.luxValue
    }
    
    // MARK: - Body
    var body: some View {
//        GlassEffectContainer(spacing: 8.0) {
            HStack(spacing: 8) {
                Group {
                    if connectionState == .connected {
                        VStack {
                            Gauge(
                                value: animatedLuxProgress,
                                in: 0...1,
                                label: { Label("Lux", systemImage: "sun.max.fill") },
                                currentValueLabel: { Text("\(Int(luxValue)) lx") }
                            )
                            .gaugeStyle(.accessoryCircular)
                            .tint(.yellow)
                            .scaleEffect(0.5)
                        }
                        //.frame(width: 20, height: 20)
                        //.padding()
                        //.glassEffect()
                        //.glassEffectUnion(id: "luxMeter", namespace: namespace)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    
                }
                .onAppear {
                    // Initialize the gauge’s fill
                    animatedLuxProgress = luxProgress
                }
                .onChange(of: luxProgress) { oldProgress, newProgress in
                    // Smoothly animate whenever the normalized value changes
                    withAnimation(.smooth(duration: 3.0)) {
                        animatedLuxProgress = newProgress
                    }
                }
                ZStack(alignment: .trailing) {
                    // Signal view branch
                    if showSignalView {
                        HStack(spacing: 4) {
                            SignalStrengthView(rssi: signalStrength)
                            
                            ConnectionStateIconView(state: connectionState)
                                .id(connectionState)
                        }
                        .padding()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        // Ensure the outgoing view is on top when state changes
                        .zIndex(showSignalView ? 0 : 1)
                    }

                    // Text branch
                    if !showSignalView {
                        HStack(spacing: 4){
                            Text(connectionStatus)
                                .font(.caption)
                                .foregroundStyle(connectionState.color) // Get the color directly from the extension on ConnectionState.
                                .id(connectionStatus)
                                .lineLimit(1)
                                //.minimumScaleFactor(0.5)
                                //.padding()
                                
                            ConnectionStateIconView(state: connectionState)
                                .id(connectionState)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        // Ensure the outgoing view is on top when state changes
                        .zIndex(showSignalView ? 1 : 0)
                        .padding()
                    }
                }
                .clipped()
            }
//    }
        // The .animation modifier on the container animates all changes within it,
        // including the icon replacement and text transitions.
        .animation(.smooth(duration: 0.35), value: showSignalView)
        .animation(.smooth(duration: 0.35), value: connectionStatus)
        .animation(.bouncy(duration: 0.4), value: connectionState)
        //.padding(10)
        //.glassEffect()
    }
}

