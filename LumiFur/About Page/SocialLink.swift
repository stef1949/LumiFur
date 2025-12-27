//
//  SocialLink.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/20/25.
//

import SwiftUI

struct SocialLink: View {
    let imageName: String
    let appURL: URL
    let webURL: URL

    @Environment(\.openURL) var openURL

    var body: some View {
        Button {
            // Try opening the app URL first
            if UIApplication.shared.canOpenURL(appURL) {
                openURL(appURL)
            } else {
                // Fallback to web
                openURL(webURL)
            }
        } label: {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .tint(.primary)
                .opacity(0.5)
                .frame(width: 25, height: 25)
        }
        .drawingGroup()
    }
}
