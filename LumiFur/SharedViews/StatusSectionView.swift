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
        let _ = IdleCPUDiagnostics.shared.recordViewBody("StatusSectionView")

        HStack(spacing: 8) {
            // Lux badge (render only when connected); otherwise keep layout with a lightweight placeholder
            if connectionState == .connected {
                LuxBadgeView(progress: luxProgress, luxValue: luxValue)
                    .equatable()
                    .padding(.horizontal, 4)
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
            .animation(.easeInOut(duration: 0.25), value: showSignalView)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
    }

    private struct LuxBadgeView: View, Equatable {
        let progress: Double
        let luxValue: Double
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(luxTintColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(luxValue))")
                    .font(.system(size: 8, weight: .semibold))
            }
            .frame(width: 22, height: 22)
            .animation(.easeInOut(duration: 2.0), value: progress)
        }
        private var luxTintColor: Color {
            if progress < 0.2 {
                return Color.blue
            } else if progress < 0.5 {
                return Color.green
            } else if progress < 0.8 {
                return Color.yellow
            } else {
                return Color.orange
            }
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
