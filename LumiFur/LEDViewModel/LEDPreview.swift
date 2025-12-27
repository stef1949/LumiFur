//
//  LEDPreview.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 12/26/25.
//
import SwiftUI

struct LEDPreview: View {
    @Binding var ledStates: [[Color]]

    var activeColor: Color = .white
    var isErasing: Bool = false
    var brushRadius: Int = 0
    var canDraw: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            let states = ledStates
            let xCount = states.count
            let yCount = states.first?.count ?? 0

            if xCount > 0, yCount > 0 {
                let ledWidth  = geometry.size.width  / CGFloat(xCount)
                let ledHeight = geometry.size.height / CGFloat(yCount)
                let rectWidth  = ledWidth  - 1
                let rectHeight = ledHeight - 1

                // Quick check: any lit pixels?
                let hasGlow = states.contains { column in
                    column.contains { $0 != .black }
                }

                Canvas { context, _ in
                    // 1️⃣ Base pixels (including "off" LEDs)
                    context.blendMode = .normal

                    for x in 0..<xCount {
                        let xOffset = CGFloat(x) * ledWidth
                        for y in 0..<yCount {
                            let yOffset = CGFloat(y) * ledHeight
                            let baseColor = states[x][y]

                            let displayColor: Color = (baseColor == .black)
                                ? Color(white: 0.06)   // dark package for off LED
                                : baseColor

                            let rect = CGRect(
                                x: xOffset,
                                y: yOffset,
                                width: rectWidth,
                                height: rectHeight
                            )

                            context.fill(Path(rect), with: .color(displayColor))
                        }
                    }

                    // 2️⃣ Glow only if needed
                    guard hasGlow else { return }

                    context.blendMode = .plusLighter

                    for x in 0..<xCount {
                        let xOffset = CGFloat(x) * ledWidth
                        for y in 0..<yCount {
                            let baseColor = states[x][y]
                            guard baseColor != .black else { continue }

                            let yOffset = CGFloat(y) * ledHeight
                            let rect = CGRect(
                                x: xOffset,
                                y: yOffset,
                                width: rectWidth,
                                height: rectHeight
                            )

                            let center = CGPoint(x: rect.midX, y: rect.midY)
                            let radius = max(rectWidth, rectHeight) * 1.6

                            let glowRect = CGRect(
                                x: center.x - radius / 2,
                                y: center.y - radius / 2,
                                width: radius,
                                height: radius
                            )

                            context.fill(
                                Path(ellipseIn: glowRect),
                                with: .radialGradient(
                                    Gradient(colors: [
                                        baseColor.opacity(0.55),
                                        .clear
                                    ]),
                                    center: center,
                                    startRadius: 0,
                                    endRadius: radius
                                )
                            )
                        }
                    }
                }
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
                //.background(Color.black)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard canDraw else { return }
                            let col = Int(value.location.x / ledWidth)
                            let row = Int(value.location.y / ledHeight)
                            applyBrush(atCol: col, row: row)
                        }
                )
            } else {
                // Fallback if grid is empty
                Color.clear
            }
        }
        .aspectRatio(64.0 / 32.0, contentMode: .fit)
        .padding(10)
    }

    // MARK: - Drawing logic

    private func applyBrush(atCol col: Int, row: Int) {
        let xCount = ledStates.count
        let yCount = ledStates.first?.count ?? 0
        guard xCount > 0, yCount > 0 else { return }

        let radius = max(0, brushRadius)
        let colorToSet: Color = isErasing ? .black : activeColor

        // Clamp brush bounds
        let minX = max(0, col - radius)
        let maxX = min(xCount - 1, col + radius)
        let minY = max(0, row - radius)
        let maxY = min(yCount - 1, row + radius)

        // 🔐 If we're completely outside the grid, bail out
        guard minX <= maxX, minY <= maxY else { return }

        for x in minX...maxX {
            for y in minY...maxY {
                ledStates[x][y] = colorToSet
            }
        }
    }
}
