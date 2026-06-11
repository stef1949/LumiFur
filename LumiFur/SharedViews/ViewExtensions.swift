//
//  ViewExtensions.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//

import SwiftUI

struct CompatibleNavigationStack<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        Text(attributedString)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private var attributedString: AttributedString {
        if let parsed = try? AttributedString(markdown: markdown) {
            return parsed
        }

        return AttributedString(markdown)
    }
}

struct LegacyUnavailableView: View {
    let title: String
    let systemImage: String
    let description: String?

    init(_ title: String, systemImage: String, description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            if let description {
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

extension View {
    func legacyGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func compatibleClearPopoverPresentation() -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground(.clear)
                .presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatiblePopoverPresentation() -> some View {
        if #available(iOS 16.4, *) {
            presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleSheetPresentation(cornerRadius: CGFloat? = nil) -> some View {
        if #available(iOS 16.4, *) {
            if let cornerRadius {
                presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(cornerRadius)
            } else {
                presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        } else if #available(iOS 16.0, *) {
            presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleScrollClipDisabled(_ disabled: Bool = true) -> some View {
        if #available(iOS 17.0, *) {
            scrollClipDisabled(disabled)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleScrollDismissesKeyboard() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.automatic)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatibleHideTabBar() -> some View {
        if #available(iOS 16.0, *) {
            toolbar(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}

/*
extension View {
    // Reusable function to display and animate the "Protogen" image

    func animatedProtogenImage(yOffset: Binding<CGFloat>, animationDirection: Bool, animationDuration: Double) -> some View {
        Image("Page23-2")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: yOffset.wrappedValue)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                    yOffset.wrappedValue = animationDirection ? -20 : 20
                }
            }
    }
}
*/


// 2) Equatable, value‑only button so SwiftUI can skip it when inputs don’t change
struct BouncingButton<Label: View>: View{
    let action: () -> Void
    let label: Label

    @State private var isPressed = false
    private let spring = Animation.spring(response: 0.3, dampingFraction: 0.5)

    init(action: @escaping () -> Void,
             @ViewBuilder label: @escaping () -> Label)
        {
            self.action = action
            self.label = label()
        }

    var body: some View {
        Button {
            // animate press
            withAnimation(spring) { isPressed = true }
            action()
            // animate release
            DispatchQueue.main.asyncAfter(deadline: .now()+0.15) {
                withAnimation(spring) { isPressed = false }
            }
        } label: {
            label
                .scaleEffect(isPressed ? 0.8 : 1.0)
                .animation(spring, value: isPressed)
        }
        //.buttonStyle(.glass)
        .legacyGlassBackground(cornerRadius: 16)
    }
}


public struct GradientToggleStyle: ToggleStyle {
    var gradient: LinearGradient

    public init(gradient: LinearGradient) {
        self.gradient = gradient
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    configuration.isOn.toggle()
                }
            }) {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(configuration.isOn ?
                              AnyShapeStyle(gradient) :
                              AnyShapeStyle(Color(UIColor.systemGray4)))
                        .frame(width: 51, height: 31)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .padding(2)
                        .shadow(radius: 1)
                }
                .animation(.easeInOut(duration: 0.3), value: configuration.isOn)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
