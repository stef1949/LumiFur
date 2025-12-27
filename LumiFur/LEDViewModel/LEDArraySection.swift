//
//  LEDArraySection.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/26/25.
//
import SwiftUI

struct LEDArraySection: View {
    @Binding var ledStates: [[Color]]
    var isErasing: Bool
    var brushRadius: Int
    var canDraw: Bool
    var activeColor: Color
    
    var body: some View {
        VStack {
            LEDPreview(
                ledStates: $ledStates,
                activeColor: activeColor,
                isErasing: isErasing,
                brushRadius: brushRadius,
                canDraw: canDraw
            )
        }
        /*
        .onAppear {
            ledModel.ledStates = ledStates
        }
        .onChange(of: ledStates) { oldValue, newValue in
            ledModel.ledStates = newValue
        }
          */
    }
}
