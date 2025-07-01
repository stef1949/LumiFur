//
//  ReleaseNotesView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI
import MarkdownUI

struct ReleaseNotesView: View {
    @State private var releases: [GitHubRelease] = []
    @State private var isLoading = true // Start in loading state
    @State private var errorMessage: String? = nil
    
    private let githubService = GitHubService() // Instance of the service
    
    var body: some View {
        Group { // Use Group to switch between views based on state
            if isLoading {
                ProgressView("Loading Release Notes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else if let errorMsg = errorMessage {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                    Text("Failed to Load Notes")
                        .font(.headline)
                    Text(errorMsg)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadReleases()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else if releases.isEmpty {
                Text("No release notes found.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            } else {
                // Display fetched releases in a List
                List {
                    ForEach(releases) { release in
                        Section {
                            if let releaseBody = release.body {
                                // Use MarkdownUI to render GitHub-flavored Markdown
                                Markdown(releaseBody)
                                //.lineSpacing(5)
                                    .environment(\.openURL, OpenURLAction { url in
                                        print("Opening URL: \(url)")
                                        return .systemAction
                                    })
                            } else {
                                Text("No details provided.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(5)
                            }
                        } header: {
                            HStack {
                                Text(release.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                                
                                
                                Spacer()
                                Text(release.publishedAt, style: .date) // Format date
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        // Use clear background if your List has a colored background overall
                        // .listRowBackground(Color.clear)
                    }
                }
                // Optional: Apply List style if needed
                // .listStyle(.plain)
            }
        }
        .navigationTitle("Release Notes")
        //.navigationBarTitleDisplayMode(.inline)
        // Use .task for async operations tied to view lifecycle
        .task {
            await loadReleases()
        }
    }
    
    // Function to load releases using the service
    private func loadReleases() async {
        // Reset state before loading
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedReleases = try await githubService.fetchReleases()
            // Update state on the main thread
            await MainActor.run {
                self.releases = fetchedReleases
                self.isLoading = false
            }
        } catch {
            // Update state on the main thread
            await MainActor.run {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? "An unexpected error occurred."
                self.isLoading = false
            }
        }
    }
}
