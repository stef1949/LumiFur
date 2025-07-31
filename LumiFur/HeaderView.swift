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

    // It OWNS and MANAGES the state for its child's animation.
    @State private var showSignalView: Bool = false
    
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
                showSignalView: self.showSignalView // It passes its own state down.
            )
        }
        .padding(.horizontal)
        // The logic for CHANGING the state lives here.
        .onChange(of: connectionState) { _, newValue in
            withAnimation {
                // When the connectionState from the parent changes,
                // this view updates its local @State property.
                self.showSignalView = (newValue == .connected)
            }
        }
        .onAppear {
            // This ensures the view has the correct state when it first appears.
            self.showSignalView = (connectionState == .connected)
        }
    }
}
