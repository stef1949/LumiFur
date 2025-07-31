import Testing
@testable import LumiFur
import Foundation

@Suite("GitHubService - Decoding and Error Handling")
struct GitHubServiceTests {
    @Test("Decodes GitHubRelease from valid JSON")
    func testGitHubReleaseDecoding() async throws {
        let json = #"[
          {
            "id": 1,
            "tag_name": "v1.0.0",
            "name": "Initial Release",
            "body": "This is the first release.",
            "published_at": "2023-11-10T12:00:00Z"
          }
        ]"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let releases = try decoder.decode([GitHubRelease].self, from: data)
        #expect(releases.count == 1)
        #expect(releases[0].tagName == "v1.0.0")
        #expect(releases[0].displayName == "Initial Release")
    }

    @Test("NetworkError produces correct descriptions")
    func testNetworkErrorDescriptions() async throws {
        let error = NetworkError.requestFailed(statusCode: 404)
        #expect(error.localizedDescription.contains("404"))
    }
}
