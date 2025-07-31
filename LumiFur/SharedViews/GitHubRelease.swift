import Foundation

// MARK: - Model

// Represents a single release from the GitHub API.
// Conformance to Equatable and Hashable is synthesized by the compiler.
struct GitHubRelease: Codable, Identifiable, Hashable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
    }

    // Computed property for a user-facing release name.
    var displayName: String {
        name ?? tagName
    }
}

// MARK: - Networking

// Defines structured, typed errors for network operations.
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case serverError(statusCode: Int, response: String?)
    case decodingFailed(Error)
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .serverError(let code, let response):
            let details = response ?? "No additional details."
            return "The server returned an error. Status Code: \(code). Details: \(details)"
        case .decodingFailed(let error):
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .other(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// A service class responsible for fetching data from the GitHub API.
final class GitHubService {
    // Repository details should be immutable.
    private let owner: String
    private let repo: String

    // A static, pre-configured JSON decoder is more efficient.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // The URLSession can be shared across instances.
    private let session: URLSession

    // MARK: - Initialization
    
    init(owner: String, repo: String, session: URLSession = .shared) {
        self.owner = owner
        self.repo = repo
        self.session = session
    }

    // Fetches the latest releases from the configured GitHub repository.
    func fetchReleases() async throws -> [GitHubRelease] {
        let url = try makeReleasesURL()
        let request = makeURLRequest(for: url)
        
        // Modern async/await API for URLSession. [1, 8]
        let (data, response) = try await session.data(for: request)
        
        // Ensure the response is a valid HTTP response.
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.other(URLError(.badServerResponse))
        }

        // Validate the HTTP status code. [6]
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, response: responseBody)
        }
        
        // Decode the JSON data, wrapping any decoding errors. [6]
        do {
            return try Self.decoder.decode([GitHubRelease].self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    // MARK: - Private Helpers
    
    // Constructs the URL for the releases endpoint.
    private func makeReleasesURL() throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/releases"
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        return url
    }
    
    // Creates and configures a URLRequest with standard GitHub API headers.
    private func makeURLRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("LumiFur/1.0", forHTTPHeaderField: "User-Agent")
        // No need to set the HTTP method; it defaults to GET.
        return request
    }
}
