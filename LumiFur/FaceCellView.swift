//
//  FaceCellView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/6/25.
//
import SwiftUI

struct FaceCellView: View, Equatable {
    let item: FaceItem
    let faceNumber: Int
    let isSelected: Bool
    let overlayColor: Color
    let backgroundColor: Color
    let showsMenuButton: Bool
    let onMenuTap: (() -> Void)?
    let action: (FaceItem) -> Void

    init(
        item: FaceItem,
        faceNumber: Int,
        isSelected: Bool,
        overlayColor: Color,
        backgroundColor: Color,
        showsMenuButton: Bool = false,
        onMenuTap: (() -> Void)? = nil,
        action: @escaping (FaceItem) -> Void
    ) {
        self.item = item
        self.faceNumber = faceNumber
        self.isSelected = isSelected
        self.overlayColor = overlayColor
        self.backgroundColor = backgroundColor
        self.showsMenuButton = showsMenuButton
        self.onMenuTap = onMenuTap
        self.action = action
    }

    static func == (lhs: FaceCellView, rhs: FaceCellView) -> Bool {
        lhs.item == rhs.item &&
        lhs.faceNumber == rhs.faceNumber &&
        lhs.isSelected == rhs.isSelected &&
        lhs.overlayColor == rhs.overlayColor &&
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.showsMenuButton == rhs.showsMenuButton
    }

    var body: some View {
        let fgStyle = AnyShapeStyle(isSelected ? backgroundColor : overlayColor)
        let bgStyle = AnyShapeStyle(backgroundColor)
        let overlayStyle = AnyShapeStyle(overlayColor)

        ZStack(alignment: .topTrailing) {
            Button {
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
                action(item)
            } label: {
                contentView
                    .foregroundStyle(fgStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Face \(faceNumber), \(item.content.accessibilityName)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Activates this face on the LumiFur controller")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(backgroundColor, overlayColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if showsMenuButton, let onMenuTap {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? backgroundColor : overlayColor)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel("Strobe settings")
                .accessibilityHint("Shows controls for the selected strobe face")
            }
        }
        .frame(maxWidth: 160, maxHeight: 160)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(bgStyle)
                //.background(.ultraThinMaterial) // Disabling reduces likelihood of Core Animation dying while copying a layer’s render tree
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(overlayStyle)
                        .opacity(isSelected ? 1 : 0)
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.content {
        case .emoji(let e):
            Text(e).font(.system(size: 40))
        case .symbol(let s):
            Image(systemName: s)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .padding(40)
        }
    }
}
