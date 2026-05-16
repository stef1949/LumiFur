//
//  OnboardingModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 08/05/2026.
//

import SwiftUI
import Foundation


struct Onboarding: Identifiable {
    var id = UUID()
    var title: String
    var headline: String
    var image: String
    var gradientColors: [Color]
}

