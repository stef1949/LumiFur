//
//  GitHubRelease.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 3/31/25.
//
import Foundation

// Represents a single release fetched from the GitHub API
struct GitHubRelease: Codable, Identifiable, Hashable {
    let id: Int // Use GitHub's ID, good for Identifiable
    let tagName: String // e.g., "v1.1.0"
    let name: String? // Release title, often same as tagName
    let body: String? // The actual release notes (often Markdown)
    let publishedAt: Date // Date of publication

    // Map snake_case JSON keys to camelCase Swift properties
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
    }

    // Optional: Computed property for display name
    var displayName: String {
        name ?? tagName // Use name if available, otherwise tag
    }

    // Required for Hashable conformance if you don't synthesize
     func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }

     static func == (lhs: GitHubRelease, rhs: GitHubRelease) -> Bool {
         lhs.id == rhs.id
     }
}

// Custom Error type for networking
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided was invalid."
        case .requestFailed(let code): return "The network request failed with status code: \(code)."
        case .decodingFailed(let error): return "Failed to decode the response: \(error.localizedDescription)"
        case .unknown(let error): return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

class GitHubService {
    // Replace with YOUR repository details
    private let owner = "stef1949" // << CHANGE THIS
    private let repo = "LumiFur_Controller"   // << CHANGE THIS
    
    // Fetches the latest releases from the specified GitHub repository
    func fetchReleases() async throws -> [GitHubRelease] {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases"
        print("--- GitHubService: Attempting to fetch releases ---")
        print("GitHubService: Request URL: \(urlString)") // Log the exact URL
        
        guard let url = URL(string: urlString) else {
            print("GitHubService: ERROR - Invalid URL created.")
            throw NetworkError.invalidURL
        }
        
        // Configure JSON Decoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            // Prepare Request
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("X-GitHub-Api-Version", forHTTPHeaderField: "2022-11-28") // Good practice to specify version
            // Optional: Add User-Agent
            request.setValue("LumiFur/1.0", forHTTPHeaderField: "User-Agent") // Replace YourAppName
            
            print("GitHubService: Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("GitHubService: ERROR - Response is not HTTPURLResponse.")
                throw NetworkError.unknown(NSError(domain: "HTTPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type received"]))
            }
            
            print("GitHubService: Received HTTP status code: \(httpResponse.statusCode)") // Log the status code
            
            // Check for non-successful status codes
            guard (200..<300).contains(httpResponse.statusCode) else {
                // Attempt to decode error message from GitHub if present
                var errorDetail = "Status code: \(httpResponse.statusCode)"
                if let responseBody = String(data: data, encoding: .utf8), !responseBody.isEmpty {
                    print("GitHubService: ERROR - Response Body: \(responseBody)") // Log error body
                    errorDetail += " - Body: \(responseBody)"
                } else {
                    print("GitHubService: ERROR - Response body is empty or could not be read.")
                }
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
            }
            
            // Attempt to Decode the JSON data
            print("GitHubService: Response OK. Attempting to decode JSON...")
            let releases = try decoder.decode([GitHubRelease].self, from: data)
            print("GitHubService: Successfully decoded \(releases.count) releases.")
            print("--- GitHubService: Fetch successful ---")
            return releases
            
        } catch let decodingError as DecodingError {
            print("GitHubService: ERROR - Decoding failed.")
            // Provide detailed decoding error information
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("  Type '\(type)' mismatch:", context.debugDescription)
                print("  codingPath:", context.codingPath)
            case .valueNotFound(let type, let context):
                print("  Value '\(type)' not found:", context.debugDescription)
                print("  codingPath:", context.codingPath)
            case .keyNotFound(let key, let context):
                print("  Key '\(key)' not found:", context.debugDescription)
                print("  codingPath:", context.codingPath)
            case .dataCorrupted(let context):
                print("  Data corrupted:", context.debugDescription)
                print("  codingPath:", context.codingPath)
            @unknown default:
                print("  Unknown decoding error: \(decodingError.localizedDescription)")
            }
            print("--- GitHubService: Fetch failed due to decoding error ---")
            throw NetworkError.decodingFailed(decodingError)
        } catch let networkError as NetworkError {
            // Already logged specific network errors (invalid URL, failed status code)
            print("GitHubService: ERROR - Network Error: \(networkError.localizedDescription)")
            print("--- GitHubService: Fetch failed due to network error ---")
            throw networkError
        } catch {
            print("GitHubService: ERROR - An unexpected error occurred: \(error)")
            print("--- GitHubService: Fetch failed due to unknown error ---")
            throw NetworkError.unknown(error)
        }
    }}
