//
//  OnboardingModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 08/05/2026.
//

import Foundation
import SwiftUI

struct Onboarding: Identifiable {
    let id: String
    let title: String
    let headline: String
    let image: String
    let systemImage: String
    let highlights: [String]
    let gradientColors: [Color]
    let accentColor: Color
}
