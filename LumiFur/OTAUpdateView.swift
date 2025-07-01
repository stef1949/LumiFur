//
//  OTAUpdateView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/7/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct OTAUpdateView: View {
    @ObservedObject var viewModel: AccessoryViewModel
    @State private var showingFileImporter = false

    var body: some View {
        VStack(spacing: 24) {
            if #available(iOS 18.0, *) {
                Image(systemName: "arrow.up.circle.dotted")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white, .blue.opacity(0.5))
                    .symbolRenderingMode(.palette)
                    .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
            } else {
                Image(systemName: "arrow.up.circle.dotted")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white, .blue.opacity(0.5))
                    .symbolRenderingMode(.palette)
            }
            Text("Firmware Update")
                            .font(.title2)
                            .fontWeight(.semibold)

                        // Progress bar
                        if viewModel.otaProgress > 0 {
                            VStack(spacing: 8) {
                                ProgressView(value: viewModel.otaProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                Text(String(format: "%.0f%% Complete", viewModel.otaProgress * 100))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                        }

                        // Status message
                        if !viewModel.otaStatusMessage.isEmpty {
                            Text(viewModel.otaStatusMessage)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .foregroundColor(viewModel.otaStatusMessage.contains("Error") ? .red : .primary)
                        }

                        // Show "Select Firmware" only if not updating
                        if viewModel.otaProgress == 0 {
                            Button("Select Firmware") {
                                showingFileImporter = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        // Show "Abort Update" only while updating
                        if viewModel.otaProgress > 0 {
                            Button("Abort Update") {
                                viewModel.abortOTAUpdate()
                            }
                            .foregroundColor(.red)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .fileImporter(
                        isPresented: $showingFileImporter,
                        allowedContentTypes: [.item],
                        allowsMultipleSelection: false
                    ) { result in
                        do {
                            guard let selectedFile = try result.get().first else { return }
                            if selectedFile.startAccessingSecurityScopedResource() {
                                defer { selectedFile.stopAccessingSecurityScopedResource() }
                                let firmwareData = try Data(contentsOf: selectedFile)
                                DispatchQueue.main.async {
                                    viewModel.startOTAUpdate(firmwareData: firmwareData)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    viewModel.otaStatusMessage = "Cannot access selected file (security scope denied)."
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                viewModel.otaStatusMessage = "Failed to load firmware: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
