//
//  StatusSectionView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI

struct StatusSectionView: View {
    @State private var animatedLuxProgress: Double = 0.0
    @State var shouldShowLux = false
    @Namespace private var namespace
    
    // MARK: - Properties
    let connectionState: ConnectionState
    let connectionStatus: String
    let signalStrength: Int
    let showSignalView: Bool
    let luxValue: Double
    
    // Define your min/max lux values here or pass them in
    let minLux: Double = 1
    let maxLux: Double = 4097 // max value
    
    // Normalize to 0…1 on a log scale
    private var luxProgress: Double {
        // clamp to avoid log(0)
        let clamped = min(max(luxValue, minLux), maxLux)
        // compute logs (base-10 here, but natural log works too)
        let logMin   = log10(minLux)
        let logMax   = log10(maxLux)
        let logValue = log10(clamped)
        return (logValue - logMin) / (logMax - logMin)
    }
    
    let gradient = Gradient(colors: [.clear, .yellow])
    
    // MARK: - Body
    var body: some View {
        GlassEffectContainer(spacing: 8.0) {
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
                        .frame(width: 20, height: 20)
                        .padding()
                        .glassEffect()
                        .glassEffectUnion(id: "luxMeter", namespace: namespace)
                        //.transition(.move(edge: .trailing).combined(with: .opacity))
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
                
                    if showSignalView {
                        HStack(spacing: 4) {
                            
                            SignalStrengthView(rssi: signalStrength)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            
                            ConnectionStateIconView(state: connectionState)
                                .id(connectionState)
                        }
                        //.padding()
                        .padding(.leading, 10)
                        .glassEffect()
                        .glassEffectUnion(id: "connectionGroup", namespace: namespace)
                    }
                    
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundStyle(connectionState.color) // Get the color directly from the extension on ConnectionState.
                        .id(connectionStatus)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.vertical)
                        .padding(.horizontal)
                        .glassEffect()
                        .glassEffectUnion(id: "connectionGroup", namespace: namespace)
            }
    }
        // The .animation modifier on the container animates all changes within it,
        // including the icon replacement and text transitions.
        //.animation(.bouncy(duration: 0.4), value: connectionState)
        //.padding(10)
        //.glassEffect()
    }
}
