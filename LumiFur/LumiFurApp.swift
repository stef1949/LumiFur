//
//  LumiFurApp.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI

struct RepositoryConfig {
    let appRepoName: String
    let appRepoOwner: String = "stef1949"
    let controllerRepoName: String
    let controllerRepoOwner: String = "stef1949"
    // Default values are less critical here if always injected, but still good practice
    static let defaultValues = RepositoryConfig(
        appRepoName: "stef1949/LumiFur",
        controllerRepoName: "stef1949/LumiFur_Controller"
    )
}

// 2. EnvironmentKey (can be private if only used within this file scope)
private struct RepositoryConfigurationKey: EnvironmentKey {
    static let defaultValue: RepositoryConfig = RepositoryConfig.defaultValues
}

// 3. Extension on EnvironmentValues
extension EnvironmentValues {
    var repositoryConfig: RepositoryConfig {
        get { self[RepositoryConfigurationKey.self] }
        set { self[RepositoryConfigurationKey.self] = newValue }
    }
}

@main
struct LumiFurApp: App {
    @StateObject private var appContext = LumiFurAppContext()

    let repositoryConfiguration = RepositoryConfig(
        appRepoName: "stef1949/LumiFur",          // App Repo
        controllerRepoName: "stef1949/LumiFur_Controller"  // Controller Repo
    )
    var body: some Scene {
        WindowGroup {
            RootView(appContext: appContext)
                .environment(\.repositoryConfig, repositoryConfiguration) // <<< CHECK THIS LINE
        }
    }
}

@MainActor
final class LumiFurAppContext: ObservableObject {
    let accessoryViewModel: AccessoryViewModel
    let watchConnectivityManager: WatchConnectivityManager

    init(
        accessoryViewModel: AccessoryViewModel = AccessoryViewModel(),
        watchConnectivityManager: WatchConnectivityManager = .shared
    ) {
        self.accessoryViewModel = accessoryViewModel
        self.watchConnectivityManager = watchConnectivityManager
        self.watchConnectivityManager.attach(accessoryViewModel: accessoryViewModel)
    }
}

struct RootView: View {
    @ObservedObject var appContext: LumiFurAppContext
    @StateObject private var releaseViewModel = ReleaseViewModel(
        appReleaseService: GitHubService(owner: "stef1949", repo: "LumiFur"),
        controllerReleaseService: GitHubService(owner: "stef1949", repo: "LumiFur_Controller")
    )
    // Persist the last app version that has acknowledged the "What's New" sheet.
    @AppStorage("lastAppVersion") private var lastAppVersion: String = ""
    // Get the current version from the bundle
    private let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    // Controls whether to show the "What's New" sheet.
    @State private var showWhatsNew: Bool = false
    
    //@State private var showSplash = true
    
    var body: some View {
        /*
         ZStack{
         if showSplash {
         SplashView(showSplash: $showSplash)
         }
         */
        // RootView2()
        ContentView(bleModel: appContext.accessoryViewModel)
            .sheet(isPresented: $showWhatsNew, onDismiss: markCurrentVersionSeen) {
                WhatsNew(
                    appReleases: releaseViewModel.appReleases,
                    isLoadingReleases: releaseViewModel.isLoadingAppReleases,
                    releaseError: releaseViewModel.appReleaseError,
                    onRetry: {
                        Task {
                            await releaseViewModel.loadAppReleases()
                        }
                    }
                )
            }
            .onAppear(perform: updateWhatsNewPresentation)
            .task(id: showWhatsNew) {
                await loadWhatsNewReleasesIfNeeded()
            }
        // }
    }

    private func updateWhatsNewPresentation() {
        guard !lastAppVersion.isEmpty else {
            markCurrentVersionSeen()
            return
        }

        showWhatsNew = lastAppVersion != currentVersion
    }

    private func markCurrentVersionSeen() {
        lastAppVersion = currentVersion
        showWhatsNew = false
    }

    private func loadWhatsNewReleasesIfNeeded() async {
        guard showWhatsNew,
              releaseViewModel.appReleases.isEmpty,
              !releaseViewModel.isLoadingAppReleases else {
            return
        }

        await releaseViewModel.loadAppReleases()
    }
}
