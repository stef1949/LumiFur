//
//  LEDPreview.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/18/25.
//
import SwiftUI

struct LEDPreview: View {
    @ObservedObject var model: LEDPreviewModel

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                snapshot
                    .resizable()
                    .aspectRatio(64 / 32, contentMode: .fit)
            } else {
                Color.white
                    .aspectRatio(64 / 32, contentMode: .fit)
            }
        }
        .padding(10)
    }
}
