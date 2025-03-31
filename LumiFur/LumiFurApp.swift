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
    //@StateObject private var AccessoryViewModel = AccessoryViewModel.shared
    let repositoryConfiguration = RepositoryConfig(
            appRepoName: "stef1949/LumiFur",          // Actual App Repo
            controllerRepoName: "stef1949/LumiFur_Controller"  // Actual Controller Repo
        )
    var body: some Scene {
        WindowGroup {
            RootView()
            //ContentView()
                .environment(\.repositoryConfig, repositoryConfiguration) // <<< CHECK THIS LINE
        }
    }
}

struct RootView: View {
    // Persist the last shown version
    @AppStorage("lastAppVersion") private var lastAppVersion: String = ""
    // Get the current version from the bundle
    private let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    // Controls whether to show the splash screen
    @State private var showWhatsNew: Bool = false
    
    
    
    var body: some View {
        ContentView()
            .sheet(isPresented: $showWhatsNew) {
                // Present WhatsNew as a full screen cover
                WhatsNew()
            }
            .onAppear {
                // Compare stored version with current version
                if lastAppVersion != currentVersion {
                    showWhatsNew = true
                }
            }
    }
}
