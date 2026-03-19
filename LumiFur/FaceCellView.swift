//
//  FaceCellView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 8/6/25.
//
import SwiftUI

struct FaceCellView: View, Equatable {
    let item: FaceItem
    let isSelected: Bool
    let overlayColor: Color
    let backgroundColor: Color
    let showsMenuButton: Bool
    let onMenuTap: (() -> Void)?
    let action: (FaceItem) -> Void

    init(
        item: FaceItem,
        isSelected: Bool,
        overlayColor: Color,
        backgroundColor: Color,
        showsMenuButton: Bool = false,
        onMenuTap: (() -> Void)? = nil,
        action: @escaping (FaceItem) -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.overlayColor = overlayColor
        self.backgroundColor = backgroundColor
        self.showsMenuButton = showsMenuButton
        self.onMenuTap = onMenuTap
        self.action = action
    }

    static func == (lhs: FaceCellView, rhs: FaceCellView) -> Bool {
        lhs.item == rhs.item &&
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
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.prepare()
                gen.impactOccurred()
                action(item)
            } label: {
                contentView
                    .foregroundStyle(fgStyle)
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content.blur(radius: phase.isIdentity ? 0 : 5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)

            if showsMenuButton, let onMenuTap {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? backgroundColor : overlayColor)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
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
