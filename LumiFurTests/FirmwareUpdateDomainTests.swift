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

    @Test("Firmware selection never falls back to boot, partition or merged flash images")
    func preferredAssetRejectsNonApplicationImages() {
        let names = ["partitions.bin", "bootloader.bin", "boot_app0.bin", "ota_data_initial.bin", "otadata.bin", "firmware-merged.bin"]
        let assets = names.enumerated().map { makeAsset(id: $0.offset, name: $0.element) }
        let release = GitHubRelease(id: 4, tagName: "v5.0.2", name: nil, body: nil, publishedAt: .now, assets: assets)
        #expect(release.preferredFirmwareAsset == nil)
        let withApplication = GitHubRelease(id: 5, tagName: "v5.0.2", name: nil, body: nil, publishedAt: .now,
                                            assets: assets + [makeAsset(id: 6, name: "controller.bin")])
        #expect(withApplication.preferredFirmwareAsset?.name == "controller.bin")
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
    @Test("START and END need both ATT and firmware acknowledgements, in either order")
    func controlAcknowledgements() {
        for command: UInt8 in [0x01, 0x03] {
            var attFirst = OTAWriteAcknowledgement(command: command, requiresFirmwareResponse: true)
            attFirst.acknowledgeTransport()
            #expect(!attFirst.isComplete)
            attFirst.receive(AccessoryOTAResponse(code: command, detail: 0))
            #expect(attFirst.isComplete)

            var firmwareFirst = OTAWriteAcknowledgement(command: command, requiresFirmwareResponse: true)
            firmwareFirst.receive(AccessoryOTAResponse(code: command, detail: 0))
            #expect(!firmwareFirst.isComplete)
            firmwareFirst.acknowledgeTransport()
            #expect(firmwareFirst.isComplete)
        }
    }

    @Test("Unrelated, malformed and error notifications cannot acknowledge END")
    func rejectsUnrelatedAcknowledgements() {
        var pending = OTAWriteAcknowledgement(command: 0x03, requiresFirmwareResponse: true)
        pending.acknowledgeTransport()
        for response in [
            AccessoryOTAResponse(code: 0x01, detail: 0),
            AccessoryOTAResponse(code: 0x03, detail: 1),
            AccessoryOTAResponse(code: 0xFF, detail: 8)
        ] {
            pending.receive(response)
            #expect(!pending.isComplete)
        }
        #expect(AccessoryNotificationParser.otaResponse(from: Data([0xFF, 8]))?.isError == true)
        #expect(AccessoryNotificationParser.otaResponse(from: Data([0x03])) == nil)
    }

    @Test("Chunk acknowledgements are negotiated without breaking legacy START")
    func chunkAcknowledgementCompatibility() {
        #expect(AccessoryCommandEncoder.otaStart(size: 0x123456) == Data([1, 0x56, 0x34, 0x12, 0]))
        #expect(AccessoryCommandEncoder.otaStart(size: 0x123456, requestChunkAcknowledgements: true)
                == Data([1, 0x56, 0x34, 0x12, 0, 1]))
        let legacy = AccessoryNotificationParser.otaResponse(from: Data([1, 0]))!
        let current = AccessoryNotificationParser.otaResponse(from: Data([1, 1]))!
        #expect(!legacy.supportsChunkAcknowledgements)
        #expect(current.supportsChunkAcknowledgements)
        for enabled in [false, true] {
            var pending = OTAWriteAcknowledgement(command: 2, requiresFirmwareResponse: enabled)
            pending.acknowledgeTransport()
            #expect(pending.isComplete == !enabled)
            pending.receive(AccessoryOTAResponse(code: 2, detail: 0))
            #expect(pending.isComplete)
        }
    }

    @Test("OTA packets respect minimum ATT MTU and the controller worker's 512-byte limit")
    func chunkLimits() {
        for (maximum, expected) in [(0, 0), (1, 0), (20, 19), (182, 181), (512, 511), (514, 511)] {
            #expect(OTAProtocol.chunkPayloadSize(maximumWriteLength: maximum) == expected)
        }
        let firmware = Data((0..<37).map(UInt8.init))
        let chunks = stride(from: 0, to: firmware.count, by: 19).map { start in
            AccessoryCommandEncoder.otaChunk(from: firmware, range: start..<min(start + 19, firmware.count))
        }
        #expect(chunks.map(\.count) == [20, 19])
        #expect(chunks.reduce(into: Data()) { $0.append($1.dropFirst()) } == firmware)
    }

    @Test("Finalization retains full upload progress")
    func finalizationProgress() {
        #expect(AccessoryViewModel.OTAState.finalizing.progress == 1)
        #expect(AccessoryViewModel.OTAState.completed.progress == 1)
    }

    @Test("Five-byte settings from legacy firmware remain readable after reconnect")
    func legacyConfiguration() {
        #expect(AccessoryNotificationParser.configuration(from: Data([1, 0, 1, 0, 1]))?.mouthBrightnessOverrideEnabled == false)
        #expect(AccessoryNotificationParser.configuration(from: Data([1, 0, 1, 0, 1, 1]))?.mouthBrightnessOverrideEnabled == true)
    }

}
