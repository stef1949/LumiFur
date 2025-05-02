//
//  ReleaseViewModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 3/31/25.
//
import SwiftUI

@MainActor
class ReleaseViewModel: ObservableObject {
    // Keep the published state properties
    @Published var appReleases: [GitHubRelease] = []
    @Published var controllerReleases: [GitHubRelease] = []
    @Published var isLoadingAppReleases: Bool = false
    @Published var isLoadingControllerReleases: Bool = false
    @Published var appReleaseError: Error?
    @Published var controllerReleaseError: Error?

    // Keep the GitHubService instance
    private let gitHubService = GitHubService()

    // No config stored here!
    // No init needed (or use default init())

    // Method now accepts owner/repo parameters
    func loadAppReleases(owner: String, repo: String) async {
        isLoadingAppReleases = true
        appReleaseError = nil
        do {
            // Use passed-in parameters
            appReleases = try await gitHubService.fetchReleases()
        } catch {
            appReleaseError = error
            print("Error loading app releases (\(owner)/\(repo)): \(error.localizedDescription)")
        }
        isLoadingAppReleases = false
    }

    // Method now accepts owner/repo parameters
    func loadControllerReleases(owner: String, repo: String) async {
        isLoadingControllerReleases = true
        controllerReleaseError = nil
        do {
            // Use passed-in parameters
            controllerReleases = try await gitHubService.fetchReleases()
        } catch {
            controllerReleaseError = error
            print("Error loading controller releases (\(owner)/\(repo)): \(error.localizedDescription)")
        }
        isLoadingControllerReleases = false
    }
}

@ViewBuilder
 func repositoryLink(repoName: String) -> some View {
    // Assuming GitHub URLs, adjust base URL if needed
    let baseURL = "https://github.com/"
    if let url = URL(string: baseURL + repoName) {
        Link(repoName, destination: url).lineLimit(1).truncationMode(.middle)
    } else {
        Text(repoName).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
    }
}

@ViewBuilder
 func releaseRow(for release: GitHubRelease) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        // Display Release Name/Tag and Date
        HStack {
            Text(release.displayName)
                .font(.headline)
                .lineLimit(1) // Ensure name doesn't wrap excessively
            Spacer() // Push date to the right
            Text(release.publishedAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // Display Release Body (Notes)
        // Use optional chaining and nil-coalescing for the body.
        // Use .prefix() to limit initial display length.
        // Use .fixedSize to allow text to wrap correctly within limits.
        Text(release.body?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ?? "No description provided.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(4) // Limit number of lines shown
            .fixedSize(horizontal: false, vertical: true) // Allows text wrapping
        
        // --- Optional: Add Read More ---
        // Show 'Read More' if the body text was truncated
        // Note: Simple prefix check isn't foolproof for truncation, but gives an idea
        if let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), body.count > 200 {
            Button("Read More...") {
                // TODO: Implement showing full body (e.g., navigate, show sheet)
                print("Show full body for release: \(release.displayName)")
            }
            .font(.caption)
            .padding(.top, 1)
        }
    }
}
