//
//  OnboardingView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import SwiftUI

struct OnboardingView: View {
    
    @State private var showOnboarding: Bool = false
    
    var onboardingItems: [Onboarding] = onboardingData
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        
        TabView {
            ForEach(onboardingData[0...5]) { item in
                OnboardingCardView(onboarding: item)
            }
        }
        
        .tabViewStyle(PageTabViewStyle())
        .padding(.vertical, 20)
        
        Button("Show Onboarding") {
            showOnboarding.toggle()
        }
        
    }
}

#Preview {
    OnboardingView()
}
