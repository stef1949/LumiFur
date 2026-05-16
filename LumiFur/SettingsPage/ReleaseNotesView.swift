//
//  ReleaseNotesView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI
//import MarkdownUI
import Textual

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
        List {
            LazyVStack(alignment: .leading, spacing: 6, pinnedViews: []) {
                Section {
                    ForEach(releases) { release in
                        // Use a more detailed row for this view.
                        releaseDetailCard(for: release)
                            .cornerRadius(20)
                            .padding(.vertical, 10)
                    }
                }
                //.formStyle(.grouped)
            }
            //.listStyle(.insetGrouped)
            .listRowBackground(Color.clear)
            //.padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
        //.listSectionSeparator(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .border(.green)
        
    }
    
    
    /*
     struct CustomBlockStyle: StructuredText.BlockQuoteStyle {
     private static let fontScales: [CGFloat] = [2, 1.5, 1.25, 1, 0.875, 0.85]
     
     func makeBody(configuration: Configuration) -> some View {
     let blockLevel = min(configuration.blockLevel, 2)
     let fontScale = Self.fontScales[blockLevel - 5]
     
     VStack(alignment: .leading, spacing: 0) {
     configuration.label
     .textual.fontScale(0.7)
     .fontWeight(.semibold)
     
     if blockLevel == 1 {
     Divider()
     .textual.padding(.top, .fontScaled(0.25))
     }
     }
     .textual.blockSpacing(.fontScaled(top: 1.5, bottom: 0.5))
     }
     }
     */
    
    /// A view builder for displaying a single release with its full, rendered notes.
    @ViewBuilder
    private func releaseDetailCard(for release: GitHubRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header for the release
            HStack {
                Text(release.displayName)
                //.font(.title2.bold())
                Spacer()
                Text(release.publishedAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Render the release notes using Texrual.
            // This will correctly format headers, lists, links, etc.
            StructuredText(markdown: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "_No release notes provided._")
                .textual.structuredTextStyle(.gitHub)
                .textual.headingStyle(CustomHeadingStyle())
            //.textual.inlineStyle(.gitHub) // Use a nice built-in theme
                .frame(maxWidth: .infinity, alignment: .leading)
                .textual.fontScale(0.8)
            //.textual.blockSpacing(StructuredText.BlockSpacing(top: 1, bottom: 1))
            //.textual.blockQuoteStyle(CustomBlockStyle())
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        //.cornerRadius(12)
    }
}

struct CustomHeadingStyle: StructuredText.HeadingStyle {
    private static let fontScales: [CGFloat] = [0.8, 0.6, 0.5, 0.4, 0.375, 0.25]
    
    func makeBody(configuration: Configuration) -> some View {
        let headingLevel = min(configuration.headingLevel, 6)
        let fontScale = Self.fontScales[headingLevel - 1]
        
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
                .textual.fontScale(fontScale)
                //.listRowSeparator(.hidden)
            //.fontWeight(.semibold)
            
             if headingLevel == 1 {
             
             //.listRowSeparator(.hidden)
             }
        }
        .textual.blockSpacing(.fontScaled(top: 1.5, bottom: 0.5))
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

