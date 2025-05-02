//
//  cpuUsageData.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/09/2024.
//

import Foundation

struct CPUUsageDataPoint: Identifiable {
    var id = UUID()
    var timestamp: Date
    var cpuUsage: Double

    init(secondsAgo: Int, cpuUsage: Double) {
        self.timestamp = Date().addingTimeInterval(TimeInterval(-secondsAgo))
        self.cpuUsage = cpuUsage
    }
}
