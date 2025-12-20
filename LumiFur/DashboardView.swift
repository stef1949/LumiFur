//
//  DashboardView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @StateObject private var viewModel: iOSViewModel

    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = true
    @AppStorage("autoBrightness") private var autoBrightness = true
    @AppStorage("accelerometer") private var accelerometer = true
    @AppStorage("sleepMode") private var sleepMode = true
    @AppStorage("auroraMode") private var auroraMode = true
    @AppStorage("customMessage") private var customMessage = false
    @AppStorage("charts") private var isChartsExpanded = false

    @State private var customMessageText: String = ""
    @State private var showCustomMessagePopup = false
    @State private var showSplash = true

    private let twoRowOptionGrid = [
        GridItem(.adaptive(minimum: 25, maximum: 250))
    ]

    init(bleModel: AccessoryViewModel) {
        self.bleModel = bleModel
        _viewModel = StateObject(wrappedValue: iOSViewModel(accessoryViewModel: bleModel))
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    HeaderView(
                        connectionState: bleModel.connectionState,
                        connectionStatus: bleModel.connectionStatus,
                        signalStrength: bleModel.signalStrength,
                        luxValue: Double(bleModel.luxValue)
                    )
                    .equatable()
                }
                optionGridSection
                FaceGridSection(
                    selectedView: bleModel.selectedView,
                    onSetView: { bleModel.setView($0) },
                    auroraModeEnabled: auroraMode
                )
                .equatable()
                .zIndex(-1)

                ChartView(isExpanded: $isChartsExpanded, accessoryViewModel: bleModel)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 32))
                    .frame(maxHeight: isChartsExpanded ? 160 : 55)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isChartsExpanded)
            }
            .onChange(of: viewModel.receivedFaceFromWatch) { _, newFace in
                handleWatchFaceSelection(face: newFace)
            }

            if !hasLaunchedBefore && showSplash {
                SplashView(showSplash: $showSplash)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        )
                    )
            }
        }
    }

    // Define data structure for options
    private struct OptionConfig: Identifiable {
        let id = UUID()
        let title: String
        let binding: Binding<Bool>
        let type: OptionType
        let action: ((Bool) -> Void)?

        init(
            title: String,
            binding: Binding<Bool>,
            type: OptionType,
            action: ((Bool) -> Void)? = nil
        ) {
            self.title = title
            self.binding = binding
            self.type = type
            self.action = action
        }
    }

    private var standardOptions: [OptionConfig] {
        [
            OptionConfig(
                title: "Auto Brightness",
                binding: $autoBrightness,
                type: .autoBrightness
            ) { newValue in
                print("Auto brightness changed to \(newValue)")
            },
            OptionConfig(
                title: "Accelerometer",
                binding: $accelerometer,
                type: .accelerometer
            ) { newValue in
                print("Accelerometer changed to \(newValue)")
            },
            OptionConfig(
                title: "Sleep Mode",
                binding: $sleepMode,
                type: .sleepMode
            ) { newValue in
                print("Sleep mode changed to \(newValue)")
            },
            OptionConfig(
                title: "Aurora Mode",
                binding: $auroraMode,
                type: .auroraMode
            ) { newValue in
                print("Aurora Mode changed to \(newValue)")
            },
        ]
    }

    private var optionGridSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: twoRowOptionGrid) {
                ForEach(standardOptions) { option in
                    OptionToggleView(
                        title: option.title,
                        isOn: option.binding,
                        optionType: option.type
                    )
                    .onChange(of: option.binding.wrappedValue) { _, newValue in
                        option.action?(newValue)
                    }
                }
                OptionToggleView(
                    title: "Custom Message",
                    isOn: $customMessage,
                    optionType: .customMessage
                )
                .onChange(of: customMessage) { _, newValue in
                    if newValue {
                        showCustomMessagePopup = true
                    }
                }
                .popover(
                    isPresented: $showCustomMessagePopup,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    customMessagePopoverView
                        .presentationBackground(.clear)
                        .presentationCompactAdaptation(.popover)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
        .scrollClipDisabled(true)
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private var customMessagePopoverView: some View {
        VStack(spacing: 12) {
            Text("Custom Message")
                .font(.headline)
            TextField("Type…", text: $customMessageText)
                .autocorrectionDisabled(true)
            HStack {
                Spacer()
                Button("Cancel") {
                    customMessage = false
                    showCustomMessagePopup = false
                }
                Button("OK") {
                    showCustomMessagePopup = false
                    print("Custom message set: \(customMessageText)")
                }
            }
        }
        .padding(12)
        .frame(width: 300, height: 140)
    }

    private func handleWatchFaceSelection(face: String?) {
        guard let selectedFace = face else {
            print("Watch face selection cleared or invalid.")
            return
        }

        if let index = SharedOptions.protoActionOptions3.firstIndex(where: { action in
            switch action {
            case .emoji(let e): return e == selectedFace
            case .symbol(let s): return s == selectedFace
            }
        }) {
            let viewToSet = index + 1
            print(
                "Watch requested face '\(selectedFace)' at index \(index). Setting view \(viewToSet)."
            )
            bleModel.setView(viewToSet)
        } else {
            print(
                "Received face '\(selectedFace)' from watch, but it wasn’t in protoActionOptions3."
            )
        }
    }
}
