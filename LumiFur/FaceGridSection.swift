//
//  FaceGridSection.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/6/25.
//


import AVKit
import Charts
import Combine
import CoreBluetooth
import CoreHaptics
import CoreImage
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers
import os

struct FaceGridSection: View {
        // No longer observing the whole VM, but taking specific values/callbacks
        let selectedView: Int
        let onSetView: (Int) -> Void  // Callback to update the selection
        let auroraModeEnabled: Bool
        //let items: [SharedOptions.ProtoAction]  // Pass the data directly
        
        @Environment(\.colorScheme) private var colorScheme
        
        // Computed once per body re-evaluation of FaceGridSection
        private var lightColor: Color {
            colorScheme == .dark ? .white : .black }
        private var darkColor: Color {
            colorScheme == .dark ? .black : .init(UIColor.systemGray5)
        }
        
        // Make grid configuration static so it's not re-created
        private static let twoColumnGrid = [
            GridItem(.adaptive(minimum: 100, maximum: 250))
        ]
        
        /*
        // The tap action now uses the passed-in callback and selectedView
        private func faceTap(_ faceIndex: Int) {
            guard faceIndex != selectedView else { return }
            onSetView(faceIndex)
        }
        */
        
        // Access the static property directly and use .map to convert it.
        private static let items: [FaceItem] = SharedOptions.protoActionOptions3.map { FaceItem(content: $0) }
        
        
        // --- The rest of your view remains the same ---
        @State private var selectedItemID: FaceItem.ID?
        
        //@Namespace private var glassNamespace
        
        var body: some View {
            /*
             // --- DEBUG TEXT ---
             Text("Number of items: \(items.count)")
             .foregroundColor(.red)
             .font(.headline)
             .padding()
             */
           // GlassEffectContainer {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Self.twoColumnGrid) {  // Use Self.twoColumnGrid
                        // 2. ForEach loops over identifiable data, not indices.
                        ForEach(Self.items) { item in
                            FaceCellView(
                                // 3. Pass the item and selection state cleanly.
                                item: item,
                                isSelected: selectedItemID == item.id,
                                auroraModeEnabled: auroraModeEnabled,
                                overlayColor: lightColor,
                                backgroundColor: darkColor
                                //namespace: glassNamespace,
                                
                                // The action now provides the item directly.
                            ) {tappedItem in
                                // Update selection state using the stable ID
                                selectedItemID = tappedItem.id
                                // 2. Find the 0-based index of the tapped item in our array.
                                if let index = Self.items.firstIndex(where: { $0.id == tappedItem.id }) {
                                    // 3. Convert to the 1-based command index that the hardware expects.
                                    let commandIndex = index + 1
                                    // 4. Call the parent's `onSetView` function to send the command.
                                    onSetView(commandIndex)
                                    // Optional but recommended: Add a print statement for debugging.
                                    print("Tapped item with content '\(tappedItem.content)'. Sending command for view: \(commandIndex)")                            }
                            }
                            .equatable() // This is good, keep it!
                        }
                    }
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)
                    //.border(.red)
                }
                .scrollDismissesKeyboard(.automatic)
                .scrollClipDisabled()
            //}
            // This watches for external changes (e.g., from the watch) and updates the local UI.
            .onChange(of: selectedView) { _, newViewIndex in
                let modelIndex = newViewIndex - 1
                if Self.items.indices.contains(modelIndex) {
                    selectedItemID = Self.items[modelIndex].id
                } else {
                    selectedItemID = nil // Deselect if index is out of bounds
                }
            }
        }
    }
