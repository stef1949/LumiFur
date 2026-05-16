//
//  OTAUpdateView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/7/25.
//


import SwiftUI
import UniformTypeIdentifiers
//import MarkdownUI
import Textual

struct OTAUpdateView: View {
    @ObservedObject var viewModel: AccessoryViewModel
    @ObservedObject var releaseViewModel: ReleaseViewModel
    @StateObject private var coordinator = FirmwareUpdateCoordinator()
    @State private var showingFileImporter = false

    var body: some View {
        List {
            headerSection
            versionSection
            progressSection
            actionSection
            recoverySection
            releaseNotesSection
        }
        .navigationTitle("Firmware Update")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            coordinator.attach(releaseViewModel: releaseViewModel)
            await coordinator.refresh(usingInstalledFirmware: viewModel.firmwareVersion)
        }
        .onChange(of: viewModel.firmwareVersion) { _, newValue in
            coordinator.updateInstalledVersion(newValue)
        }
        .onChange(of: releaseViewModel.controllerReleases) { _, _ in
            coordinator.refreshSelection(usingInstalledFirmware: viewModel.firmwareVersion)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            coordinator.handleLocalFirmwareSelection(result: result) { data in
                viewModel.startOTAUpdate(firmwareData: data)
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.dotted")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.white, .blue.opacity(0.55))
                    .symbolRenderingMode(.palette)

                Text("Update your LumiFur controller firmware safely and keep your effects up to date.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var versionSection: some View {
        Section("Firmware Status") {
            statusRow(
                title: "Installed",
                value: coordinator.installedVersionDisplay,
                valueColor: .primary
            )

            statusRow(
                title: "Latest",
                value: coordinator.latestVersionDisplay,
                valueColor: .primary
            )

            HStack {
                Text("Status")
                Spacer()
                Text(coordinator.firmwareStatus.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(coordinator.firmwareStatus.color, in: Capsule())
            }
        }
    }

    private var progressSection: some View {
        Section("Progress") {
            if coordinator.isCheckingReleases {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking latest firmware releases…")
                }
            }

            if coordinator.isDownloading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Downloading \(coordinator.downloadedAssetName)")
                        .font(.subheadline)
                    ProgressView(value: coordinator.downloadProgress)
                    Text("\(Int(coordinator.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let integrityMessage = coordinator.downloadIntegrityMessage {
                Text(integrityMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if viewModel.otaState.isActive || viewModel.otaState == .completed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.otaStatusMessage)
                        .font(.subheadline)
                        .foregroundStyle(viewModel.otaState.isError ? .red : .primary)
                    if viewModel.otaProgress > 0 {
                        ProgressView(value: viewModel.otaProgress)
                        Text("\(Int(viewModel.otaProgress * 100))% uploaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let remaining = viewModel.otaEstimatedRemainingSeconds {
                        Text("Estimated remaining: \(formatRemainingTime(remaining))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage = coordinator.lastError {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var actionSection: some View {
        Section("Actions") {
            Button {
                Task {
                    await coordinator.refresh(usingInstalledFirmware: viewModel.firmwareVersion, force: true)
                }
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise")
            }
            .disabled(coordinator.isBusy)

            Button {
                Task {
                    await coordinator.downloadLatestFirmware()
                }
            } label: {
                Label(coordinator.downloadButtonTitle, systemImage: "arrow.down.circle")
            }
            .disabled(!coordinator.canDownloadLatest || coordinator.isBusy)

            Button {
                if let downloaded = coordinator.consumeDownloadedFirmwareData() {
                    viewModel.startOTAUpdate(firmwareData: downloaded)
                }
            } label: {
                Label("Start OTA Upload", systemImage: "arrow.up.circle")
            }
            .disabled(coordinator.downloadedFirmwareData == nil || viewModel.otaState.isActive || !viewModel.isConnected)

            Button {
                showingFileImporter = true
            } label: {
                Label("Select Local Firmware File", systemImage: "folder")
            }
            .disabled(viewModel.otaState.isActive || coordinator.isBusy)

            if viewModel.otaState.isActive {
                Button(role: .destructive) {
                    viewModel.abortOTAUpdate()
                } label: {
                    Label("Abort OTA Upload", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var recoverySection: some View {
        Section("Recovery") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Keep the controller powered and near your iPhone until the upload finishes.", systemImage: "bolt.horizontal.circle")
                Label("If an upload fails, leave the controller on, reconnect in Bluetooth settings, then retry the same firmware file.", systemImage: "arrow.clockwise.circle")
                Label("If the controller does not respond after retrying, power-cycle it once before starting another upload.", systemImage: "power.circle")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var releaseNotesSection: some View {
        Section("Release Notes") {
            if let release = coordinator.selectedRelease {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(release.displayName)
                            .font(.headline)
                        Spacer()
                        Text(release.publishedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let asset = coordinator.selectedAsset {
                        Text("Selected asset: \(asset.name) (\(ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    StructuredText(markdown: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "_No release notes provided._")
                        //.markdownTheme(.gitHub)
                }
            } else if coordinator.isCheckingReleases {
                Text("Loading release notes…")
                    .foregroundStyle(.secondary)
            } else {
                Text("No firmware release data is available yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusRow(title: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        if totalSeconds < 60 {
            return "< 1 min"
        }

        let minutes = totalSeconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(minutes)m"
    }
}

@MainActor
private final class FirmwareUpdateCoordinator: ObservableObject {
    enum FirmwareStatus {
        case upToDate
        case updateAvailable
        case unableToDetermine

        var label: String {
            switch self {
            case .upToDate:
                return "Up to date"
            case .updateAvailable:
                return "Update available"
            case .unableToDetermine:
                return "Unable to determine"
            }
        }

        var color: Color {
            switch self {
            case .upToDate:
                return .green
            case .updateAvailable:
                return .orange
            case .unableToDetermine:
                return .gray
            }
        }
    }

    @Published private(set) var selectedRelease: GitHubRelease?
    @Published private(set) var selectedAsset: GitHubReleaseAsset?
    @Published private(set) var firmwareStatus: FirmwareStatus = .unableToDetermine
    @Published private(set) var installedVersionDisplay: String = "Unknown"
    @Published private(set) var latestVersionDisplay: String = "Unknown"
    @Published private(set) var isCheckingReleases = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var downloadedFirmwareData: Data?
    @Published private(set) var downloadedAssetName = "firmware.bin"
    @Published private(set) var downloadIntegrityMessage: String?
    @Published private(set) var lastError: String?

    var isBusy: Bool { isCheckingReleases || isDownloading }
    var canDownloadLatest: Bool { selectedRelease != nil && selectedAsset != nil }

    var downloadButtonTitle: String {
        guard let release = selectedRelease else { return "Download Latest Firmware" }
        let tag = SemanticVersion.parse(release.tagName)?.displayString ?? release.tagName
        return "Download Firmware \(tag)"
    }

    private var releaseViewModel: ReleaseViewModel?
    private let firmwareService = GitHubService(owner: "stef1949", repo: "LumiFur_Controller")

    func attach(releaseViewModel: ReleaseViewModel) {
        self.releaseViewModel = releaseViewModel
    }

    func consumeDownloadedFirmwareData() -> Data? {
        guard let data = downloadedFirmwareData else { return nil }
        downloadedFirmwareData = nil
        return data
    }

    func refresh(usingInstalledFirmware installedVersion: String, force: Bool = false) async {
        guard let releaseViewModel else { return }

        isCheckingReleases = true
        lastError = nil
        defer { isCheckingReleases = false }

        if force || releaseViewModel.controllerReleases.isEmpty {
            await releaseViewModel.loadControllerReleases()
        }

        if let fetchError = releaseViewModel.controllerReleaseError {
            lastError = fetchError.localizedDescription
        }

        refreshSelection(usingInstalledFirmware: installedVersion)
    }

    func refreshSelection(usingInstalledFirmware installedVersion: String) {
        updateInstalledVersion(installedVersion)

        let releases = releaseViewModel?.controllerReleases ?? []
        selectedRelease = releases.max { lhs, rhs in
            let lhsVersion = lhs.semanticVersion
            let rhsVersion = rhs.semanticVersion
            switch (lhsVersion, rhsVersion) {
            case let (left?, right?):
                return left < right
            default:
                return lhs.publishedAt < rhs.publishedAt
            }
        }

        selectedAsset = selectedRelease?.preferredFirmwareAsset
        latestVersionDisplay = selectedRelease
            .flatMap { SemanticVersion.parse($0.tagName)?.displayString }
            ?? selectedRelease?.tagName
            ?? "Unknown"

        evaluateFirmwareStatus()

        if selectedRelease != nil, selectedAsset == nil {
            lastError = "No suitable OTA firmware binary was found in the latest release assets."
        }
    }

    func updateInstalledVersion(_ installedVersion: String) {
        let parsed = SemanticVersion.parse(installedVersion)
        installedVersionDisplay = parsed?.displayString ?? normalizeVersionDisplay(installedVersion)
        evaluateFirmwareStatus()
    }

    func downloadLatestFirmware() async {
        guard let asset = selectedAsset else {
            lastError = "No downloadable firmware asset is available."
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadIntegrityMessage = nil
        lastError = nil
        defer { isDownloading = false }

        do {
            let data = try await firmwareService.downloadAssetData(asset) { progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress
                }
            }

            guard !data.isEmpty else {
                lastError = "Downloaded firmware file is empty."
                downloadedFirmwareData = nil
                return
            }

            downloadedFirmwareData = data
            downloadedAssetName = asset.name
            if let expectedDigest = asset.expectedSHA256Digest {
                let actualDigest = GitHubService.sha256Hex(of: data)
                downloadIntegrityMessage = actualDigest == expectedDigest
                    ? "Checksum verified against \(expectedDigest.prefix(12))…"
                    : nil
            } else {
                downloadIntegrityMessage = nil
            }
        } catch let error as NetworkError {
            lastError = error.localizedDescription
            downloadedFirmwareData = nil
            downloadIntegrityMessage = nil
        } catch {
            lastError = error.localizedDescription
            downloadedFirmwareData = nil
            downloadIntegrityMessage = nil
        }
    }

    func handleLocalFirmwareSelection(
        result: Result<[URL], Error>,
        onReady: (Data) -> Void
    ) {
        do {
            guard let selectedFile = try result.get().first else { return }
            guard selectedFile.startAccessingSecurityScopedResource() else {
                lastError = "Cannot access selected file (security scope denied)."
                return
            }
            defer { selectedFile.stopAccessingSecurityScopedResource() }

            let firmwareData = try Data(contentsOf: selectedFile)
            guard !firmwareData.isEmpty else {
                lastError = "Selected firmware file is empty."
                return
            }

            downloadedFirmwareData = firmwareData
            downloadedAssetName = selectedFile.lastPathComponent
            lastError = nil
            onReady(firmwareData)
            downloadedFirmwareData = nil
        } catch {
            lastError = "Failed to load firmware: \(error.localizedDescription)"
            downloadIntegrityMessage = nil
        }
    }

    private func evaluateFirmwareStatus() {
        guard let latest = selectedRelease?.semanticVersion else {
            firmwareStatus = .unableToDetermine
            return
        }

        guard let installed = SemanticVersion.parse(installedVersionDisplay) else {
            firmwareStatus = .unableToDetermine
            return
        }

        firmwareStatus = installed < latest ? .updateAvailable : .upToDate
    }

    private func normalizeVersionDisplay(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "N/A" || trimmed == "--" {
            return "Unknown"
        }
        return trimmed
    }
}

private extension AccessoryViewModel.OTAState {
    var isError: Bool {
        if case .failed = self { return true }
        return false
    }
}
