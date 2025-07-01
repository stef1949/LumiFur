//
//  StyledGauge.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 4/6/25.
//
import SwiftUI

struct StyledGauge: View {
    @State private var current = 47.0
    @State private var minValue = 15.0
    @State private var maxValue = 70.0
    let gradient = Gradient(colors: [.green, .yellow, .orange, .red])
    
    
    var body: some View {
        Gauge(value: current, in: minValue...maxValue) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        } currentValueLabel: {
            Text("\(Int(current))")
                .foregroundColor(Color.green)
        } minimumValueLabel: {
            Text("\(Int(minValue))")
                .foregroundColor(Color.green)
        } maximumValueLabel: {
            Text("\(Int(maxValue))")
                .foregroundColor(Color.red)
        }
        .gaugeStyle(CircularGaugeStyle(tint: gradient))
        
    }
}

struct GaugeUnit: View {
    var body: some View {
        VStack {
            StyledGauge()
            Text("Gauge")
                .font(.system(size: 10))
                .offset(y: -5)
            
        }
        .padding()
    }
}

struct CurrentViewGauge: View {
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    //@State private var selectedView: Int = 1
    var body: some View {
            Text("\(connectivityManager.selectedView)")
            .foregroundStyle(.black)
            .padding()
            .glassEffect(.regular.tint(.white))
        
    }
}
