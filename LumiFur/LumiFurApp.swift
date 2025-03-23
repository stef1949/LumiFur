//
//  LumiFurApp.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI

@main
struct LumiFurApp: App {
    //@StateObject private var AccessoryViewModel = AccessoryViewModel.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
            //ContentView()
                //.environmentObject(AccessoryViewModel)
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
            .fullScreenCover(isPresented: $showWhatsNew) {
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
