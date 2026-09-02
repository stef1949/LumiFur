//
//  FaceGridSection.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/6/25.
//

import SwiftUI

struct FaceGridSection: View {
    let selectedView: Int
    let onSetView: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var lightColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var darkColor: Color {
        colorScheme == .dark ? .black : .init(UIColor.systemGray5)
    }

    private static let twoColumnGrid = [
        GridItem(.adaptive(minimum: 100, maximum: 250))
    ]

    private static let items: [FaceItem] = SharedOptions.protoActionOptions.map {
        FaceItem(content: $0)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: Self.twoColumnGrid) {
                ForEach(Self.items.indices, id: \.self) { index in
                    let item = Self.items[index]
                    let faceNumber = index + 1

                    FaceCellView(
                        item: item,
                        faceNumber: faceNumber,
                        isSelected: selectedView == faceNumber,
                        overlayColor: lightColor,
                        backgroundColor: darkColor
                    ) { _ in
                        onSetView(faceNumber)
                    }
                    .equatable()
                }
            }
            .padding(.horizontal)
        }
        .compatibleScrollDismissesKeyboard()
        .compatibleScrollClipDisabled()
    }
}
