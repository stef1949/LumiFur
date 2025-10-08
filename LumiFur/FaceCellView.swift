//
//  FaceCellView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/6/25.
//
import SwiftUI

// MARK: – FaceCellView
// MARK: –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
// 2) Pure, Equatable cell
struct FaceCellView: View, Equatable {
    // --- PROPERTIES ---
    // 1. The data model is now a single, immutable object.
    let item: FaceItem
    
    // All other state and configuration properties remain.
    let isSelected: Bool
    let auroraModeEnabled: Bool
    let overlayColor: Color
    let backgroundColor: Color
   // let namespace: Namespace.ID
    
    // 2. The action closure now passes back the entire item. This is more robust.
    let action: (FaceItem) -> Void
    
    // This is well-implemented, no changes needed. It's correctly a @State
    // property to persist it for the view's lifetime.
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // --- EQUATABLE CONFORMANCE ---
    // 3. The comparison is now cleaner and more correct.
    // It relies on the FaceItem's own Equatable conformance.
    static func == (lhs: FaceCellView, rhs: FaceCellView) -> Bool {
        lhs.item == rhs.item &&
        lhs.isSelected == rhs.isSelected &&
        lhs.auroraModeEnabled == rhs.auroraModeEnabled &&
        lhs.overlayColor == rhs.overlayColor &&
        lhs.backgroundColor == rhs.backgroundColor
    }
    
    var body: some View {
        Button {
            // Prepare and trigger haptic feedback
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
            
            // 4. The action now passes back the stable 'item' object, not the fragile 'index'.
            action(item)
            
        } label: {
            // 5. We switch on the item's content, not a separate property.
            switch item.content {
            case .emoji(let e):
                Text(e)
                    .font(.system(size: 40))
                    .backgroundStyle(.ultraThinMaterial)
                    .foregroundStyle(isSelected ? backgroundColor : overlayColor)
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content.blur(radius: phase.isIdentity ? 0 : 5)
                    }
            case .symbol(let s):
                Image(systemName: s)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? backgroundColor : overlayColor)
                    .padding(40)
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content.blur(radius: phase.isIdentity ? 0 : 5)
                    }
            }
        }
        //.aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 160, maxHeight: 160)
        .aspectRatio(1, contentMode: .fit)
        // 6. CRITICAL: Use the item's stable 'id' for the matched geometry effect.
        // This ensures animations are always correct, even if the list is reordered.
        //.glassEffectID(item.id, in: namespace)
        /*
        .glassEffect(
            .regular.tint(isSelected ? .primary : .clear)
            .interactive(),
            in: RoundedRectangle(cornerRadius: 25)
        )
         */
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(backgroundColor)
                .overlay(
                    isSelected ?
                        RoundedRectangle(cornerRadius: 15).fill(overlayColor)
                        : nil
                )
        }        //.backgroundStyle(.ultraThinMaterial)
    }
}
