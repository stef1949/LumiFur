//
//  WhatsNew.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI

struct WhatsNew: View {
    // Persist the last shown version in user defaults
    @AppStorage("lastAppVersion") private var lastAppVersion: String = ""
    // Get the current version from the bundle (default to "1.0" if not found)
    private let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    // Controls whether the splash screen is visible
    @State private var shouldShow: Bool = true
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Group {
            if shouldShow {
                ZStack {
                    Color(.clear)
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                    VStack {
                        Spacer()
                        Text("What's New in LumiFur")
                            .font(.system(.largeTitle, weight: .bold))
                            .frame(width: 240)
                            .clipped()
                            .multilineTextAlignment(.center)
                            .padding(.top, 82)
                            .padding(.bottom, 10)
                        VStack(spacing: 28) {
                            ScrollView {
                                ForEach(widgetItems) { item in // Replace with your data model here
                                    HStack {
                                        Image(systemName: item.iconName)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.blue)
                                            .font(.system(.title, weight: .regular))
                                            .frame(width: 60, height: 50)
                                            .clipped()
                                        VStack(alignment: .leading, spacing: 3) {
                                            // Title
                                            Text(item.title)
                                                .font(.system(.footnote, weight: .semibold))
                                            // Description
                                            Text(item.description)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline) {
                            Text("Complete feature list")
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                        }
                        .padding(.top, 10)
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                        //Spacer()
                        BouncingButton(action: {
                            // Update the stored version and dismiss the splash screen
                            lastAppVersion = currentVersion
                            dismiss()
                            withAnimation { shouldShow = false }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .padding(.horizontal)
                        }
                        .padding()
                        Spacer()
                    }
                    //.background(.ultraThinMaterial)
                    .transition(.opacity)
                    .animation(.easeInOut, value: shouldShow)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .padding(.top, 53)
                    .padding(.bottom, 0)
                    .padding(.horizontal, 29)
                }
                //.padding()
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // Show the "What's New" screen if the current version differs from the last stored version
            if lastAppVersion != currentVersion {
                shouldShow = true
            }
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity)
        //.clipped()
        //.padding(.top, 53)
        //.padding(.bottom, 0)
        //.padding(.horizontal, 29)
        //.drawingGroup()
        //.compositingGroup()
    }
    }
