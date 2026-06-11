//
//  OnboardingCardView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import SwiftUI

struct OnboardingCardView: View {
    let onboarding: Onboarding

    @State private var isAnimating: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(onboarding.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Image(systemName: onboarding.systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(onboarding.accentColor)
                        .accessibilityHidden(true)

                    Text(LocalizedStringKey(onboarding.title))
                        .foregroundStyle(.white)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.82)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)

                    Text(LocalizedStringKey(onboarding.headline))
                        .foregroundColor(.white.opacity(0.88))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 520)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(onboarding.highlights, id: \.self) { highlight in
                        Label {
                            Text(LocalizedStringKey(highlight))
                                .font(.subheadline.weight(.medium))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(onboarding.accentColor)
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 440, alignment: .leading)
                .padding(18)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    OnboardingCardView(onboarding: onboardingData[0])
        .background(
            LinearGradient(
                gradient: Gradient(colors: onboardingData[0].gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}
