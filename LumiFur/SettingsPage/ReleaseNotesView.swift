//
//  ReleaseNotesView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI
import MarkdownUI

struct ReleaseNotesView: View {
    /*
     @State private var releases: [GitHubRelease] = []
     @State private var isLoading = true // Start in loading state
     @State private var errorMessage: String? = nil
     */
    let title: String
    let releases: [GitHubRelease]

    var body: some View {
            // We can use a ScrollView for better presentation of long notes.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                    ForEach(releases) { release in
                        // Use a more detailed row for this view.
                        releaseDetailCard(for: release)
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        
        /// A view builder for displaying a single release with its full, rendered notes.
        @ViewBuilder
        private func releaseDetailCard(for release: GitHubRelease) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header for the release
                HStack {
                    Text(release.displayName)
                        .font(.title2.bold())
                    Spacer()
                    Text(release.publishedAt, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Render the release notes using MarkdownUI.
                // This will correctly format headers, lists, links, etc.
                Markdown(release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "_No release notes provided._")
                    .markdownTheme(.gitHub) // Use a nice built-in theme
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Preview

    struct ReleaseNotesView_Previews: PreviewProvider {
        static var previews: some View {
            // Create sample data for the preview.
            let sampleReleases = [
                GitHubRelease(id: 1, tagName: "v1.1", name: "Major Update", body: """
                ## New Features
                - Feature A is now available.
                - Added support for **dark mode**.
                
                ## Bug Fixes
                - Fixed a crash on older devices.
                - Improved performance.
                """, publishedAt: .now),
                GitHubRelease(id: 2, tagName: "v1.0", name: "Initial Release", body: "First version of the app.", publishedAt: Date().addingTimeInterval(-100000))
            ]
            
            // Preview the view inside a NavigationStack to see the title.
            NavigationStack {
                ReleaseNotesView(title: "App Releases", releases: sampleReleases)
            }
        }
    }
