//
//  InfoView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/20/25.
//

import SwiftUI

struct InfoView: View {
    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }
    private let features: [Feature] = [
        .init(
            icon: "play.circle.fill",
            title: "Live Control",
            description: "Adjust brightness, speed & colour in real time."
        ),
        .init(
            icon: "sparkles",
            title: "Prebuilt Effects",
            description: "Pick from a gallery of dynamic patterns."
        ),
        .init(
            icon: "slider.horizontal.3",
            title: "Custom Sequences",
            description: "Compose and save your own light shows."
        ),
        .init(
        //  icon: "bluetooth.fill",
            icon: "antenna.radiowaves.left.and.right",
            title: "Bluetooth Sync",
            description: "Wireless pairing to your suit’s controller."
        ),
    ]
    var body: some View {
        NavigationStack {
            List {
                // MARK: – Logo Header
                VStack {
                    HStack {
                        Spacer()
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        Spacer()
                    }
                    Spacer()
                    HStack(spacing: 15.0) {
                        SocialLink(
                            imageName: "bluesky.fill",
                            appURL: URL(string: "bsky://profile/richies.uk")!,
                            webURL: URL(
                                string: "https://bsky.app/profile/richies.uk"
                            )!
                        )
                        SocialLink(
                            imageName: "facebook.fill",
                            appURL: URL(string: "fb://profile/richies3d")!,
                            webURL: URL(
                                string: "https://www.facebook.com/richies3d/"
                            )!
                        )
                        SocialLink(
                            imageName: "x",
                            appURL: URL(
                                string: "twitter://user?screen_name=richies3d"
                            )!,
                            webURL: URL(string: "https://x.com/Richies3D")!
                        )
                        SocialLink(
                            imageName: "github.fill",
                            appURL: URL(
                                string: "github://user?username=stef1949"
                            )!,  // GitHub’s custom scheme
                            webURL: URL(string: "https://github.com/stef1949")!
                        )
                        SocialLink(
                            imageName: "linkedin.fill",
                            appURL: URL(
                                string: "linkedin://in/stefan-ritchie"
                            )!,
                            webURL: URL(
                                string:
                                    "https://www.linkedin.com/in/stefan-ritchie/"
                            )!
                        )
                    }

                }
                //.drawingGroup()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // MARK: – About Section
                Section(header: Text("About LumiFur")) {
                    Text(
                        """
                        LumiFur is an iOS‑native companion app for controlling LEDs on fursuits. It offers an intuitive interface for ramping colours, effects and sequences—right from your pocket.
                        """
                    )
                    .font(.body)
                    //.foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }

                // MARK: – Features Section
                Section(header: Text("Features")) {
                    ForEach(features) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                //.foregroundStyle()
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.headline)
                                Text(feature.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        //.drawingGroup()
                        .padding(.vertical, 6)
                    }
                }

                // MARK: – Full List Link
                Section {
                    HStack {
                        Spacer()
                        Label(
                            "Complete feature list",
                            systemImage: "chevron.forward"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)  // iOS18 default grouping
            .scrollContentBackground(.hidden)  // let our list sit over the material
            .background(.thinMaterial)  // global bg
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
