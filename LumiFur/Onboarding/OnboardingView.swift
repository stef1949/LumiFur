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

    init(
        onboardingItems: [Onboarding] = onboardingData,
        onComplete: @escaping () -> Void = {}
    ) {
        self.onboardingItems = onboardingItems
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: selectedGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.25), value: selectedIndex)

            VStack(spacing: 16) {
                header

                if onboardingItems.isEmpty {
                    unavailableContent
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(onboardingItems.enumerated()), id: \.element.id) { index, item in
                            OnboardingCardView(onboarding: item)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    pageIndicator
                    footer
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack {
            Text("LumiFur")
                .font(Font.custom("Meloriac", size: 32))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button("Skip") {
                onComplete()
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .foregroundStyle(.white)
            .accessibilityHint("Dismisses onboarding")
        }
        .padding(.horizontal, 24)
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

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(onboardingItems.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? .white : .white.opacity(0.35))
                    .frame(width: index == selectedIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedIndex)
            }
        }
        .accessibilityLabel("Page \(selectedIndex + 1) of \(onboardingItems.count)")
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                moveBackward()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .foregroundStyle(.white)
            .opacity(selectedIndex == 0 ? 0 : 1)
            .disabled(selectedIndex == 0)

            Spacer()

            Button {
                moveForwardOrComplete()
            } label: {
                Label {
                    Text(primaryActionTitle)
                } icon: {
                    Image(systemName: primaryActionImage)
                }
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundColor(.black)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
    }

    private var selectedGradientColors: [Color] {
        guard onboardingItems.indices.contains(selectedIndex) else {
            return [Color(red: 0.04, green: 0.06, blue: 0.08), Color(red: 0.05, green: 0.35, blue: 0.42)]
        }

        return onboardingItems[selectedIndex].gradientColors
    }

    private var isLastPage: Bool {
        selectedIndex >= onboardingItems.count - 1
    }

    private var primaryActionTitle: String {
        isLastPage ? "Get Started" : "Next"
    }

    private var primaryActionImage: String {
        isLastPage ? "checkmark" : "chevron.right"
    }

    private func moveBackward() {
        selectedIndex = max(selectedIndex - 1, 0)
    }

    private func moveForwardOrComplete() {
        guard !isLastPage else {
            onComplete()
            return
        }

        selectedIndex = min(selectedIndex + 1, onboardingItems.count - 1)
    }
}

#Preview {
    OnboardingView()
}
