//
//  OnboardingData.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import Foundation
import SwiftUI

// MARK: - Onboarding data

let onboardingData: [Onboarding] = [
    Onboarding(
        id: "welcome",
        title: "Welcome to LumiFur",
        headline: "Control expressive face modes, lighting, and live controller status from one place.",
        image: "mps3",
        systemImage: "sparkles",
        highlights: [
            "Browse face presets from the dashboard",
            "Send quick lighting and motion commands",
            "Keep an eye on connection and temperature"
        ],
        gradientColors: [
            Color(red: 0.04, green: 0.06, blue: 0.08),
            Color(red: 0.05, green: 0.35, blue: 0.42)
        ],
        accentColor: Color(red: 0.23, green: 0.82, blue: 0.88)
    ),
    Onboarding(
        id: "connect",
        title: "Connect your controller",
        headline: "Use Bluetooth scanning to find a nearby LumiFur controller and reconnect to saved devices faster.",
        image: "LumiFur_Controller_AK",
        systemImage: "antenna.radiowaves.left.and.right",
        highlights: [
            "Scan from Settings when no controller is connected",
            "Reconnect to previously paired controllers",
            "See signal strength before choosing a device"
        ],
        gradientColors: [
            Color(red: 0.07, green: 0.09, blue: 0.18),
            Color(red: 0.31, green: 0.19, blue: 0.46)
        ],
        accentColor: Color(red: 0.88, green: 0.58, blue: 0.96)
    ),
    Onboarding(
        id: "customize",
        title: "Tune the experience",
        headline: "Adjust brightness, temperature units, sleep behavior, motion effects, and custom messages as your setup changes.",
        image: "Protogen",
        systemImage: "slider.horizontal.3",
        highlights: [
            "Use dashboard quick controls while connected",
            "Create custom LED views from the Custom tab",
            "Reset advanced preferences when needed"
        ],
        gradientColors: [
            Color(red: 0.05, green: 0.12, blue: 0.12),
            Color(red: 0.32, green: 0.38, blue: 0.17)
        ],
        accentColor: Color(red: 0.72, green: 0.86, blue: 0.34)
    ),
    Onboarding(
        id: "updates",
        title: "Stay current",
        headline: "Review app and controller release notes, then update compatible controller firmware from the Settings tab.",
        image: "ESP32-S3",
        systemImage: "arrow.up.circle",
        highlights: [
            "Check app and controller release notes",
            "Run OTA updates when a controller is connected",
            "Confirm firmware details after reconnecting"
        ],
        gradientColors: [
            Color(red: 0.12, green: 0.06, blue: 0.05),
            Color(red: 0.47, green: 0.18, blue: 0.11)
        ],
        accentColor: Color(red: 1.0, green: 0.58, blue: 0.35)
    )
]
