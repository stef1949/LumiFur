//
//  HeaderView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI


// Place this struct outside of ContentView
struct HeaderView: View {
    
    // MARK: - Properties
    // It receives the core data from ContentView.
    let connectionState: ConnectionState
    let connectionStatus: String
    let signalStrength: Int
    let luxValue: Double
    private var showSignalView: Bool {
        connectionState == .connected
    }
    
    // MARK: - Body
    var body: some View {
        HStack {
            Text("LumiFur")
                .font(Font.custom("Meloriac", size: 35))
                .frame(width: 150)
                //.border(.purple)
            
            Spacer()
            
            // It creates the StatusSectionView and passes down the data.
            StatusSectionView(
                connectionState: self.connectionState,
                connectionStatus: self.connectionStatus,
                signalStrength: self.signalStrength,
                showSignalView: showSignalView, // It passes the derived state down.
                luxValue: self.luxValue
            )
            .equatable()
        }
        .padding(.horizontal)
    }
}
