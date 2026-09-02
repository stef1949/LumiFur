//
//  OnboardingView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 07/05/2026.
//

import SwiftUI

struct OnboardingView: View {
    let onboardingItems: [Onboarding]
    let onComplete: () -> Void

    @State private var selectedIndex = 0

    private let pageAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    private let tint = Color(red: 0.03, green: 0.48, blue: 1.0)

    init(
        onboardingItems: [Onboarding] = onboardingData,
        onComplete: @escaping () -> Void = {}
    ) {
        self.onboardingItems = onboardingItems
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if onboardingItems.isEmpty {
                    unavailableContent
                } else {
                    onboardingContent(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }

    private func onboardingContent(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let buttonWidth = min(size.width * 0.76, 440)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer()
                    //.frame(height: previewTopPadding)

                screenshotStage
                    .frame(height: size.height * 0.57)
                    .padding(.horizontal, 8)

                textContentView
                    .frame(height: size.height * 0.12)
                    .padding(.horizontal, max(28, size.width * 0.1))
                    .padding(.top, size.height * 0.018)

                pageIndicator
                    .padding(.top, size.height * 0.024)

                if #available(iOS 26.0, *) {
                    continueButtonGlass
                        //.frame(width: buttonWidth)
                        .padding(.top, size.height * 0.026)
                } else {
                    continueButton
                        .frame(width: buttonWidth)
                        .padding(.top, size.height * 0.026)
                }
                Spacer(minLength: safeAreaInsets.bottom + 18)
            }
            .frame(width: size.width, height: size.height)

            backButton
                //.padding(.top, topChromePadding)
                .padding(.leading, max(22, size.width * 0.07))
        }
        .frame(width: size.width, height: size.height)
    }

    private var screenshotStage: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(onboardingItems.enumerated()), id: \.element.id) { index, item in
                OnboardingCardView(
                    onboarding: item,
                    previewImage: item.previewImage,
                    isSelected: index == selectedIndex,
                    activeZoomScale: item.zoomScale,
                    activeZoomAnchor: item.zoomAnchor
                )
                .onboardingPageScrollTransition(isSelected: index == selectedIndex)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(pageAnimation, value: selectedIndex)
    }

    private var textContentView: some View {
        ZStack {
            ForEach(Array(onboardingItems.enumerated()), id: \.element.id) { index, item in
                let isActive = selectedIndex == index

                VStack(spacing: 6) {
                    Text(LocalizedStringKey(item.title))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .foregroundStyle(.white)

                    Text(LocalizedStringKey(item.headline))
                        .font(.system(.callout, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .compositingGroup()
                .opacity(isActive ? 1 : 0.35)
                .blur(radius: isActive ? 0 : 24)
                .offset(y: isActive ? 0 : 10)
                .accessibilityHidden(!isActive)
            }
        }
        .animation(pageAnimation, value: selectedIndex)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(onboardingItems.indices, id: \.self) { index in
                let isActive = selectedIndex == index

                Capsule()
                    .fill(.white.opacity(isActive ? 1 : 0.4))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
        .animation(pageAnimation, value: selectedIndex)
        .accessibilityLabel("Page \(selectedIndex + 1) of \(onboardingItems.count)")
    }

    private var continueButton: some View {
        Button {
            moveForwardOrComplete()
        } label: {
            Text(isLastPage ? "Get Started" : "Continue")
                .font(.headline.weight(.medium))
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            Capsule(style: .continuous)
                .fill(tint)
                .shadow(color: tint.opacity(0.28), radius: 16, x: 0, y: 8)
        }
        .animation(pageAnimation, value: selectedIndex)
        .accessibilityHint(isLastPage ? "Completes onboarding" : "Shows the next onboarding page")
    }
    
    @available(iOS 26.0, *)
    private var continueButtonGlass: some View {
        Button {
            moveForwardOrComplete()
        } label: {
            Text(isLastPage ? "Get Started" : "Continue")
                .font(.headline.weight(.medium))
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
        .animation(pageAnimation, value: selectedIndex)
        .accessibilityHint(isLastPage ? "Completes onboarding" : "Shows the next onboarding page")
    }

    @ViewBuilder
    private var backButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                moveBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .opacity(selectedIndex > 0 ? 1 : 0.85)
            .scaleEffect(selectedIndex > 0 ? 1 : 0.96)
            .animation(pageAnimation, value: selectedIndex)
            .accessibilityLabel("Back")
        } else {
            Button {
                moveBackward()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .compatibleLiquidGlass(cornerRadius: 21, tint: .white.opacity(0.08), interactive: false)
            }
            .buttonStyle(.plain)
            .opacity(selectedIndex > 0 ? 1 : 0.85)
            .scaleEffect(selectedIndex > 0 ? 1 : 0.96)
            .animation(pageAnimation, value: selectedIndex)
            .accessibilityLabel("Back")
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
            Text("LumiFur is ready.")
                .font(.title2.weight(.semibold))
            Button("Get Started", action: onComplete)
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isLastPage: Bool {
        selectedIndex >= onboardingItems.count - 1
    }

    private func moveBackward() {
        withAnimation(pageAnimation) {
            selectedIndex = max(selectedIndex - 1, 0)
        }
    }

    private func moveForwardOrComplete() {
        withAnimation(pageAnimation) {
            if isLastPage {
                onComplete()
            } else {
                selectedIndex = min(selectedIndex + 1, onboardingItems.count - 1)
            }
        }
    }
}

#Preview {
    OnboardingView()
}

private extension View {
    @ViewBuilder
    func onboardingPageScrollTransition(isSelected: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTransition(.animated(.smooth(duration: 0.58))) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    .opacity(phase.isIdentity ? 1 : 0.58)
                    .offset(y: phase.isIdentity ? 0 : 14)
            }
        } else {
            self
                .scaleEffect(isSelected ? 1 : 0.94)
                .opacity(isSelected ? 1 : 0.62)
        }
    }
}
