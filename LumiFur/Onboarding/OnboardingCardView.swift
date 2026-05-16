//
//  OnboardingCardView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import SwiftUI

struct OnboardingCardView: View {
    
    var onboarding: Onboarding
    
    @State private var isAnimating: Bool = false
    
    var body: some View {
          ZStack {
            VStack(spacing: 20) {
              // FRUIT: IMAGE
              Image(onboarding.image)
                .resizable()
                .scaledToFit()
                .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.15), radius: 8, x: 6, y: 8)
                .scaleEffect(isAnimating ? 1.0 : 0.6)
              
              // FRUIT: TITLE
              Text(onboarding.title)
                .foregroundColor(Color.white)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.15), radius: 2, x: 2, y: 2)
              
              // FRUIT: HEADLINE
              Text(onboarding.headline)
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: 480)
              
              // BUTTON: START
              // MARK: StartButtonView()
            } //: VSTACK
          } //: ZSTACK
          .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
              isAnimating = true
            }
          }
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
          .background(LinearGradient(gradient: Gradient(colors: onboarding.gradientColors), startPoint: .top, endPoint: .bottom))
          .cornerRadius(20)
          .padding(.horizontal, 20)
        }
    }

    struct FruitCardView_Previews: PreviewProvider {
        static var previews: some View {
            OnboardingCardView(onboarding: onboardingData[0])
        }
    }
