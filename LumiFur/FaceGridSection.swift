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
    @State private var selectedItemID: FaceItem.ID?

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
                ForEach(Self.items) { item in
                    FaceCellView(
                        item: item,
                        isSelected: selectedItemID == item.id,
                        overlayColor: lightColor,
                        backgroundColor: darkColor
                    ) { tappedItem in
                        selectedItemID = tappedItem.id
                        guard let index = Self.items.firstIndex(where: { $0.id == tappedItem.id }) else {
                            return
                        }
                        onSetView(index + 1)
                    }
                    .equatable()
                }
            }
            .padding(.horizontal)
        }
        .scrollDismissesKeyboard(.automatic)
        .scrollClipDisabled()
        .onChange(of: selectedView) { _, newViewIndex in
            let modelIndex = newViewIndex - 1
            if Self.items.indices.contains(modelIndex) {
                selectedItemID = Self.items[modelIndex].id
            } else {
                selectedItemID = nil
            }
        }
    }
}
