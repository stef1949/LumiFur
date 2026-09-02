//
//  LumiFurWatchOSApp.swift
//  LumiFurWatchOS Watch App
//
//  Created by Stephan Ritchie on 2/14/25.
//

import SwiftUI

@main
struct LumiFurWatchOS_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.applicationDidBecomeActive()
                    }
                }
        }
        .backgroundTask(.watchConnectivity) {
            await model.handleBackgroundConnectivity()
        }
    }
}
