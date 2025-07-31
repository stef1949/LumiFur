import SwiftUI

// MARK: - Release View Model

@MainActor
final class ReleaseViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // State properties remain the same, with private setters for safety.
    @Published private(set) var appReleases: [GitHubRelease] = []
    @Published private(set) var isLoadingAppReleases: Bool = false
    @Published private(set) var appReleaseError: NetworkError?

    @Published private(set) var controllerReleases: [GitHubRelease] = []
    @Published private(set) var isLoadingControllerReleases: Bool = false
    @Published private(set) var controllerReleaseError: NetworkError?

    // MARK: - Private Properties
    
    private let appReleaseService: GitHubService
    private let controllerReleaseService: GitHubService

    // MARK: - Initialization

    init(
        appReleaseService: GitHubService,
        controllerReleaseService: GitHubService
    ) {
        self.appReleaseService = appReleaseService
        self.controllerReleaseService = controllerReleaseService
    }
    
    // MARK: - Public Methods

    /// Asynchronously loads releases for the app repository.
    func loadAppReleases() async {
        isLoadingAppReleases = true
        appReleaseError = nil
        // defer ensures the loading flag is reset when the function exits.
        defer { isLoadingAppReleases = false }

        let result = await fetchReleases(from: appReleaseService)
        
        switch result {
        case .success(let releases):
            self.appReleases = releases
        case .failure(let error):
            self.appReleaseError = error
        }
    }

    /// Asynchronously loads releases for the controller repository.
    func loadControllerReleases() async {
        isLoadingControllerReleases = true
        controllerReleaseError = nil
        defer { isLoadingControllerReleases = false }
        
        let result = await fetchReleases(from: controllerReleaseService)

        switch result {
        case .success(let releases):
            self.controllerReleases = releases
        case .failure(let error):
            self.controllerReleaseError = error
        }
    }

    // MARK: - Private Helper

    /// A generic, reusable function that fetches releases and returns a Result.
    /// This removes all direct state mutation, fixing the compiler errors.
    private func fetchReleases(from service: GitHubService) async -> Result<[GitHubRelease], NetworkError> {
        do {
            let releases = try await service.fetchReleases()
            return .success(releases)
        } catch let networkError as NetworkError {
            // If it's already a NetworkError, pass it along.
            return .failure(networkError)
        } catch {
            // If it's some other unexpected error, wrap it in our custom type.
            return .failure(.other(error))
        }
    }
}

// MARK: - Reusable SwiftUI Views
// (These view implementations remain unchanged as they were already well-structured)

@ViewBuilder
private func repositoryLink(owner: String, repo: String) -> some View {
    if let url = URL(string: "https://github.com/\(owner)/\(repo)") {
        Link("\(owner)/\(repo)", destination: url)
            .lineLimit(1)
            .truncationMode(.middle)
    } else {
        Text("\(owner)/\(repo)")
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

@ViewBuilder
private func releaseRow(for release: GitHubRelease) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(release.displayName)
                .font(.headline)
            Spacer()
            Text(release.publishedAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        Text(release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No release notes provided.")
            .font(.body)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        
        if let body = release.body, body.count > 250 {
            Button("Read More...") {
                print("Show full body for release: \(release.displayName)")
            }
            .font(.caption)
            .padding(.top, 2)
        }
    }
}
