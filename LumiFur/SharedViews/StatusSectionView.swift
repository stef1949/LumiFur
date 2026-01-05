//
//  StatusSectionView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI


struct ToolbarStatusModel: Equatable {
    let connectionState: ConnectionState
    let toolbarStatusText: String
    let signalStrength: Int
    let luxValue: Int
}

struct StatusSectionView: View, Equatable {

    let connectionState: ConnectionState
    let connectionStatus: String
    let signalStrength: Int
    let showSignalView: Bool
    let luxValue: Double

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.connectionState == rhs.connectionState &&
        lhs.connectionStatus == rhs.connectionStatus &&
        lhs.signalStrength == rhs.signalStrength &&
        lhs.showSignalView == rhs.showSignalView &&
        lhs.luxValue == rhs.luxValue
    }

    var body: some View {
        HStack(spacing: 8) {
            // Lux badge (render only when connected); otherwise keep layout with a lightweight placeholder
            if connectionState == .connected {
                LuxBadgeView(progress: luxProgress)
                    .equatable()
            } else {
                Color.clear
                    .frame(width: 22, height: 22)
            }

            // Content + trailing connection icon
            HStack(spacing: 4) {
                if showSignalView {
                    SignalBarsView(rssi: signalStrength)
                        .frame(width: 28)
                        .transition(.opacity)
                } else {
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundStyle(connectionState.color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                }

                // Keep the icon outside the conditional to avoid re-creating it on toggle
                ConnectionStateIconView(state: connectionState)
            }
            .frame(height: 20)
            .animation(.smooth(duration: 0.25), value: showSignalView)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
    }

    private struct LuxBadgeView: View, Equatable {
        let progress: Double

        var body: some View {
            Gauge(
                value: progress,
                in: 0...1,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(0.55)
            .frame(width: 22, height: 22)
            .animation(.smooth(duration: 2.0), value: progress)
        }
    }

    private struct SignalBarsView: View, Equatable {
        let rssi: Int

        var body: some View {
            SignalStrengthView(rssi: rssi)
        }
    }

    private static let minLux: Double = 1
    private static let maxLux: Double = 4097
    private var luxProgress: Double {
        let clamped = min(max(luxValue, Self.minLux), Self.maxLux)
        let logMin = log10(Self.minLux)
        let logMax = log10(Self.maxLux)
        let logValue = log10(clamped)
        return (logValue - logMin) / (logMax - logMin)
    }
}

