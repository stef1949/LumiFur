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
