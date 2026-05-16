//
//  WhatsNew.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI

struct WhatsNew: View {
    @Environment(\.dismiss) var dismiss
    
    let appReleases: [GitHubRelease]
    let isLoadingReleases: Bool
    let releaseError: NetworkError?
    let onRetry: (() -> Void)?
    
    var body: some View {
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
                releaseNotesContent
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
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        //.background(Color.blue)
                        //.foregroundColor(.white)
                        .cornerRadius(20)
                        //.padding(.horizontal)
                }
                .padding()
                Spacer()
            }
            //.background(.ultraThinMaterial)
            .transition(.opacity)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.top, 53)
            .padding(.bottom, 0)
            .padding(.horizontal, 29)
        }
        //.padding()
        .ignoresSafeArea()
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity)
        //.clipped()
        //.padding(.top, 53)
        //.padding(.bottom, 0)
        //.padding(.horizontal, 29)
        //.drawingGroup()
        //.compositingGroup()
    }

    @ViewBuilder
    private var releaseNotesContent: some View {
        if isLoadingReleases && appReleases.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading release notes...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if let releaseError, appReleases.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Release notes failed to load.")
                    .font(.headline)
                Text(releaseError.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let onRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if appReleases.isEmpty {
            ContentUnavailableView(
                "No Release Notes",
                systemImage: "doc.text.magnifyingglass",
                description: Text("No app release notes are available right now.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ReleaseNotesView(title: "App Releases", releases: appReleases)
                .frame(maxHeight: 360)
        }
    }
}

extension WhatsNew {
    init(
        appReleases: [GitHubRelease],
        isLoadingReleases: Bool = false,
        releaseError: NetworkError? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.appReleases = appReleases
        self.isLoadingReleases = isLoadingReleases
        self.releaseError = releaseError
        self.onRetry = onRetry
    }
}
