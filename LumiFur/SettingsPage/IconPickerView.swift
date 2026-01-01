//
//  IconPickerView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/27/25.
//

import SwiftUI

// MARK: - Model

struct AppIcon: Identifiable, Equatable {
    /// The alternate icon name used in Info.plist (nil = primary icon)
    let iconName: String?
    /// The asset name used for preview
    let assetName: String
    /// A user-friendly label
    let displayName: String

    // Use a stable ID instead of a random UUID
    var id: String { iconName ?? "primary" }
}

// MARK: - Available icons

let appIcons: [AppIcon] = [
    AppIcon(iconName: nil,            assetName: "AppIcon",       displayName: "Default"),
    AppIcon(iconName: "bluegreen",    assetName: "bluegreen",     displayName: "Blue Green"),
    AppIcon(iconName: "glassrainbow", assetName: "glassrainbow",  displayName: "Glass Rainbow"),
    AppIcon(iconName: "lilaclight",   assetName: "lilaclight",    displayName: "Lilac Light"),
    AppIcon(iconName: "monochrome",   assetName: "monochrome",    displayName: "Monochrome"),
    AppIcon(iconName: "orangebow",    assetName: "orangebow",     displayName: "Orange Bow"),
    AppIcon(iconName: "pinkbow",      assetName: "pinkbow",       displayName: "Pink Bow"),
    AppIcon(iconName: "pinkpalette",  assetName: "pinkpalette",   displayName: "Pink Palette"),
    AppIcon(iconName: "purplebow",    assetName: "purplebow",     displayName: "Purple Bow")
]

// MARK: - Icon Picker View

struct AppIconPickerView: View {
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    @State private var isChangingIcon = false
    @State private var errorMessage: String?

    #if canImport(UIKit)
    @State private var availableAlternateIcons: Set<String> = []
    @State private var supportsAlternateIcons: Bool = UIApplication.shared.supportsAlternateIcons
    #endif

    /// Optional callback to inform the parent of the currently selected icon
    var onIconChanged: ((String?) -> Void)? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(appIcons) { icon in
                        iconButton(for: icon)
                    }
                }
                .padding()
            }
            .navigationTitle("App Icon")
            .onAppear {
                loadCurrentIcon()
                #if canImport(UIKit)
                supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons
                availableAlternateIcons = configuredAlternateIconNames()
                #endif
            }
            .alert("Error changing icon", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Icon Cell

    @ViewBuilder
    private func iconPreviewImage(named name: String) -> some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .resizable()
        } else {
            Image(systemName: "app")
                .resizable()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        #else
        Image(name)
            .resizable()
        #endif
    }

    @ViewBuilder
    private func iconButton(for icon: AppIcon) -> some View {
        let isSelected = icon.iconName == currentIconName

        Button {
            changeIcon(to: icon)
        } label: {
            VStack(spacing: 6) {
                iconPreviewImage(named: icon.assetName)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor : .secondary.opacity(0.2),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .shadow(radius: isSelected ? 6 : 2)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .symbolRenderingMode(.hierarchical)
                                .padding(6)
                        }
                    }

                Text(icon.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                if isSelected {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .opacity(isChangingIcon && !isSelected ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isChangingIcon)
    }

    // MARK: - Logic

    #if canImport(UIKit)
    private func configuredAlternateIconNames() -> Set<String> {
        guard let info = Bundle.main.infoDictionary,
              let iconsDict = info["CFBundleIcons"] as? [String: Any],
              let alternates = iconsDict["CFBundleAlternateIcons"] as? [String: Any] else {
            return []
        }
        return Set(alternates.keys)
    }
    #endif

    private func loadCurrentIcon() {
        #if canImport(UIKit)
        currentIconName = UIApplication.shared.alternateIconName
        #else
        currentIconName = nil
        #endif
    }

    private func changeIcon(to icon: AppIcon) {
        // If already selected, do nothing
        guard icon.iconName != currentIconName else { return }

        isChangingIcon = true

        #if canImport(UIKit)
        // Validate platform support and configuration before attempting the change
        guard UIApplication.shared.supportsAlternateIcons else {
            self.isChangingIcon = false
            self.errorMessage = "This device does not support alternate app icons."
            return
        }
        if let name = icon.iconName {
            // Ensure the alternate name exists in Info.plist
            let configured = availableAlternateIcons
            if !configured.contains(name) {
                self.isChangingIcon = false
                self.errorMessage = "Alternate icon '" + name + "' is not configured.\nAdd a CFBundleAlternateIcons entry named '" + name + "' in Info.plist and include the icon files."
                return
            }
        }

        UIApplication.shared.setAlternateIconName(icon.iconName) { error in
            DispatchQueue.main.async {
                self.isChangingIcon = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.currentIconName = icon.iconName
                    self.onIconChanged?(icon.iconName)
                }
            }
        }
        #else
        // Non-iOS platforms: just reset state + show a friendly message if you want
        isChangingIcon = false
        errorMessage = "Changing app icons is not supported on this platform."
        self.onIconChanged?(icon.iconName)
        #endif
    }
}

// MARK: - Preview

struct AppIconPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AppIconPickerView()
        }
    }
}
