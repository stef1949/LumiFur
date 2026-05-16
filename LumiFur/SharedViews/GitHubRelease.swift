import CryptoKit
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
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case assets
    }

    init(
        id: Int,
        tagName: String,
        name: String?,
        body: String?,
        publishedAt: Date,
        assets: [GitHubReleaseAsset] = []
    ) {
        self.id = id
        self.tagName = tagName
        self.name = name
        self.body = body
        self.publishedAt = publishedAt
        self.assets = assets
    }

    // Computed property for a user-facing release name.
    var displayName: String {
        name ?? tagName
    }

    var semanticVersion: SemanticVersion? {
        SemanticVersion.parse(tagName)
    }

    var preferredFirmwareAsset: GitHubReleaseAsset? {
        if let exactFirmware = assets.first(where: { $0.name.lowercased() == "firmware.bin" }) {
            return exactFirmware
        }

        if let firstFirmwareLike = assets.first(where: { $0.isLikelyFirmwareBinary }) {
            return firstFirmwareLike
        }

        return assets.first(where: { $0.name.lowercased().hasSuffix(".bin") })
    }
}

struct GitHubReleaseAsset: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let size: Int
    let contentType: String?
    let browserDownloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case contentType = "content_type"
        case browserDownloadURL = "browser_download_url"
        case digest
    }

    init(
        id: Int,
        name: String,
        size: Int,
        contentType: String?,
        browserDownloadURL: URL,
        digest: String? = nil
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.contentType = contentType
        self.browserDownloadURL = browserDownloadURL
        self.digest = digest
    }

    var isLikelyFirmwareBinary: Bool {
        let normalized = name.lowercased()
        guard normalized.hasSuffix(".bin") else { return false }

        if normalized.contains("partition") ||
            normalized.contains("bootloader") ||
            normalized.contains("ota_data") {
            return false
        }

        return normalized.contains("firmware") || normalized.contains("app")
    }

    var expectedSHA256Digest: String? {
        guard let digest else { return nil }
        let normalized = digest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.lowercased().hasPrefix("sha256:") else { return nil }
        return String(normalized.dropFirst("sha256:".count)).lowercased()
    }
}

struct SemanticVersion: Comparable, Hashable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?

    static func parse(_ raw: String?) -> SemanticVersion? {
        guard let raw else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix = trimmed.lowercased().hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let withoutBuild = withoutPrefix.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let coreAndPrerelease = withoutBuild.first.map(String.init) ?? withoutPrefix

        let corePieces = coreAndPrerelease.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numericCore = corePieces.first.map(String.init) ?? coreAndPrerelease
        let prerelease = corePieces.count > 1 ? String(corePieces[1]) : nil

        let numbers = numericCore.split(separator: ".", omittingEmptySubsequences: false)
        guard !numbers.isEmpty else { return nil }
        guard numbers.count <= 3 else { return nil }

        guard let major = Int(numbers[0]) else { return nil }
        let minor = numbers.count > 1 ? Int(numbers[1]) : 0
        let patch = numbers.count > 2 ? Int(numbers[2]) : 0
        guard let minor, let patch else { return nil }

        return SemanticVersion(major: major, minor: minor, patch: patch, prerelease: prerelease)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case let (left?, right?):
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    var displayString: String {
        let core = "\(major).\(minor).\(patch)"
        guard let prerelease, !prerelease.isEmpty else { return core }
        return "\(core)-\(prerelease)"
    }
}

// MARK: - Networking

// Defines structured, typed errors for network operations.
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case serverError(statusCode: Int, response: String?)
    case decodingFailed(Error)
    case integrityCheckFailed(expected: String, actual: String)
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
        case .integrityCheckFailed(let expected, let actual):
            return "Downloaded firmware failed checksum verification. Expected SHA-256 \(expected), got \(actual)."
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

    func downloadAssetData(
        _ asset: GitHubReleaseAsset,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Data {
        let request = makeURLRequest(for: asset.browserDownloadURL)
        let (data, response) = try await Self.AssetDownloadDelegate(progressHandler: onProgress)
            .download(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.other(URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, response: responseBody)
        }

        if let expectedDigest = asset.expectedSHA256Digest {
            let actualDigest = Self.sha256Hex(of: data)
            guard actualDigest == expectedDigest else {
                throw NetworkError.integrityCheckFailed(expected: expectedDigest, actual: actualDigest)
            }
        }

        return data
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

    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private final class AssetDownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
        private var downloadData: Data?
        private var session: URLSession?
        private var task: URLSessionDownloadTask?
        private let progressHandler: (@Sendable (Double) -> Void)?

        init(progressHandler: (@Sendable (Double) -> Void)?) {
            self.progressHandler = progressHandler
        }

        func download(request: URLRequest) async throws -> (Data, URLResponse) {
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()

                let session = URLSession(configuration: Self.makeConfiguration(), delegate: self, delegateQueue: nil)
                lock.withLock {
                    self.session = session
                }

                return try await withCheckedThrowingContinuation { continuation in
                    let task = session.downloadTask(with: request)

                    lock.lock()
                    self.continuation = continuation
                    self.task = task
                    lock.unlock()

                    task.resume()
                }
            } onCancel: {
                self.cancelDownload()
            }
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
            progressHandler?(progress)
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            let data = try? Data(contentsOf: location, options: [.mappedIfSafe])
            lock.lock()
            downloadData = data
            lock.unlock()
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            let downloadData = self.downloadData
            let response = task.response
            self.downloadData = nil
            self.task = nil
            self.session = nil
            lock.unlock()
            defer { session.finishTasksAndInvalidate() }

            if let error {
                continuation?.resume(throwing: error)
                return
            }

            guard let downloadData, let response else {
                continuation?.resume(throwing: NetworkError.other(URLError(.cannotDecodeRawData)))
                return
            }

            continuation?.resume(returning: (downloadData, response))
        }

        private func cancelDownload() {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            self.downloadData = nil
            let task = self.task
            self.task = nil
            let session = self.session
            self.session = nil
            lock.unlock()

            task?.cancel()
            session?.invalidateAndCancel()
            continuation?.resume(throwing: CancellationError())
        }

        private static func makeConfiguration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.urlCache = nil
            configuration.httpMaximumConnectionsPerHost = 2
            return configuration
        }
    }
}
