import Foundation
import Testing
@testable import LumiFur

@Suite("Firmware Update Domain Tests")
struct FirmwareUpdateDomainTests {
    @MainActor
    private func makeViewModel(testName: String = #function) -> AccessoryViewModel {
        let suiteName = "com.richies3d.LumiFur.firmware-tests.\(testName)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StoredPeripheralStore(defaults: defaults)
        return AccessoryViewModel(client: BLEClient(), store: store, defaults: defaults)
    }

    private func makeAsset(
        id: Int,
        name: String,
        size: Int = 1024,
        contentType: String? = "application/octet-stream",
        digest: String? = nil
    ) -> GitHubReleaseAsset {
        GitHubReleaseAsset(
            id: id,
            name: name,
            size: size,
            contentType: contentType,
            browserDownloadURL: URL(string: "https://example.com/\(name)")!,
            digest: digest
        )
    }

    @Test("SemanticVersion normalizes v-prefixed tags")
    func semanticVersionParsesVPrefix() {
        let prefixed = SemanticVersion.parse("v4.2.0")
        let plain = SemanticVersion.parse("4.2.0")

        #expect(prefixed == plain)
        #expect(prefixed?.displayString == "4.2.0")
    }

    @Test("SemanticVersion handles malformed and missing values")
    func semanticVersionMalformedInput() {
        #expect(SemanticVersion.parse(nil) == nil)
        #expect(SemanticVersion.parse("") == nil)
        #expect(SemanticVersion.parse("N/A") == nil)
        #expect(SemanticVersion.parse("4.2.0.1") == nil)
        #expect(SemanticVersion.parse("v4.two.0") == nil)
    }

    @Test("SemanticVersion compares prerelease lower than stable")
    func semanticVersionComparison() {
        let prerelease = SemanticVersion.parse("4.2.0-beta.1")
        let stable = SemanticVersion.parse("4.2.0")
        let nextPatch = SemanticVersion.parse("4.2.1")

        #expect(prerelease != nil)
        #expect(stable != nil)
        #expect(nextPatch != nil)
        #expect(prerelease! < stable!)
        #expect(stable! < nextPatch!)
    }

    @Test("Preferred firmware asset picks firmware.bin when present")
    func preferredAssetPicksExactFirmwareBin() {
        let release = GitHubRelease(
            id: 1,
            tagName: "v4.2.0",
            name: "4.2.0",
            body: nil,
            publishedAt: .now,
            assets: [
                makeAsset(id: 1, name: "partitions.bin"),
                makeAsset(id: 2, name: "firmware.bin"),
                makeAsset(id: 3, name: "other.bin"),
            ]
        )

        #expect(release.preferredFirmwareAsset?.name == "firmware.bin")
    }

    @Test("Preferred firmware asset avoids partition-like binaries")
    func preferredAssetAvoidsPartitionPayload() {
        let release = GitHubRelease(
            id: 2,
            tagName: "v4.2.0",
            name: nil,
            body: nil,
            publishedAt: .now,
            assets: [
                makeAsset(id: 1, name: "partitions.bin"),
                makeAsset(id: 2, name: "LumiFur_App.bin"),
            ]
        )

        #expect(release.preferredFirmwareAsset?.name == "LumiFur_App.bin")
    }

    @Test("Preferred firmware asset falls back to first .bin")
    func preferredAssetFallsBackToFirstBin() {
        let release = GitHubRelease(
            id: 3,
            tagName: "v4.2.0",
            name: nil,
            body: nil,
            publishedAt: .now,
            assets: [
                makeAsset(id: 1, name: "misc.bin"),
                makeAsset(id: 2, name: "notes.txt", contentType: "text/plain"),
            ]
        )

        #expect(release.preferredFirmwareAsset?.name == "misc.bin")
    }

    @Test("Asset checksum parses sha256 digest prefix")
    func assetChecksumParsesDigestPrefix() {
        let asset = makeAsset(
            id: 4,
            name: "firmware.bin",
            digest: "sha256:BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
        )

        #expect(asset.expectedSHA256Digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("SHA-256 helper matches a known digest")
    func sha256HelperMatchesKnownValue() {
        let digest = GitHubService.sha256Hex(of: Data("abc".utf8))

        #expect(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("OTA start fails fast when not connected")
    @MainActor
    func otaStartDisconnectedTransitionsToFailed() {
        let vm = makeViewModel()

        vm.startOTAUpdate(firmwareData: Data([0x01, 0x02]))

        #expect(vm.otaState == .failed(message: "Peripheral not ready"))
        #expect(vm.otaProgress == 0)
        #expect(vm.otaStatusMessage == "OTA Error: Peripheral not ready")
    }

    @Test("OTA abort transitions to aborted state")
    @MainActor
    func otaAbortTransitionsToAborted() {
        let vm = makeViewModel()
        vm.otaProgress = 0.75
        vm.otaStatusMessage = "Uploading..."

        vm.abortOTAUpdate()

        #expect(vm.otaState == .aborted)
        #expect(vm.otaProgress == 0)
        #expect(vm.otaStatusMessage == "OTA Aborted")
    }
}
