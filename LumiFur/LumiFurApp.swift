//
//  LumiFurApp.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI

@main
struct LumiFurApp: App {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
        }
    }
}
