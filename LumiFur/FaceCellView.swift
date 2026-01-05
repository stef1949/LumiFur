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
    let auroraModeEnabled: Bool
    let overlayColor: Color
    let backgroundColor: Color
    let action: (FaceItem) -> Void

    static func == (lhs: FaceCellView, rhs: FaceCellView) -> Bool {
        lhs.item == rhs.item &&
        lhs.isSelected == rhs.isSelected &&
        lhs.auroraModeEnabled == rhs.auroraModeEnabled &&
        lhs.overlayColor == rhs.overlayColor &&
        lhs.backgroundColor == rhs.backgroundColor
    }

    var body: some View {
        let fgStyle = AnyShapeStyle(isSelected ? backgroundColor : overlayColor)
        let bgStyle = AnyShapeStyle(backgroundColor)
        let overlayStyle = AnyShapeStyle(overlayColor)

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
