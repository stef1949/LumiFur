//
//  OnboardingCardView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import SwiftUI

struct OnboardingCardView: View {
    let onboarding: Onboarding

    /// Image name from Assets.xcassets.
    let previewImage: String

    var isSelected: Bool = true
    var activeZoomScale: CGFloat = 1.2
    var activeZoomAnchor: UnitPoint = .bottom

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { proxy in
            Image(onboarding.previewImage)
                .resizable()
                .scaledToFit()
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .scaleEffect(
                    isSelected ? 1 : activeZoomScale,
                    anchor: activeZoomAnchor
                )
                .scaleEffect(isAnimating ? 1 : 0.94)
                .opacity(isAnimating ? 1 : 0.72)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .clipped()
                .accessibilityHidden(true)
        }
        .onAppear {
            withAnimation(
                .spring(
                    response: 0.55,
                    dampingFraction: 0.82
                )
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    OnboardingCardView(
        onboarding: onboardingData[0], previewImage: "mps3"
    )
    .background(Color.black)
}
