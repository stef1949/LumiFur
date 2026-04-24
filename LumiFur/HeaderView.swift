//
//  HeaderView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/2/25.
//
import SwiftUI


// Place this struct outside of ContentView
struct HeaderView: View, Equatable {
    
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
        let _ = IdleCPUDiagnostics.shared.recordViewBody("HeaderView")

        HStack {
            /*
            Text("LumiFur")
                .font(Font.custom("Meloriac", size: 35))
                .frame(width: 150)
                //.border(.purple)
            */
            
            // Spacer()
            
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
        //.padding(.horizontal)
    }

    static func == (lhs: HeaderView, rhs: HeaderView) -> Bool {
        lhs.connectionState == rhs.connectionState &&
        lhs.connectionStatus == rhs.connectionStatus &&
        lhs.signalStrength == rhs.signalStrength &&
        lhs.luxValue == rhs.luxValue
    }
}
