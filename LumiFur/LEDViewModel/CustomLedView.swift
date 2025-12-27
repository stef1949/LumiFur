//
//  CustomLedView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/27/25.
//

import SwiftUI

extension BinaryFloatingPoint {
    func mapped(from: ClosedRange<Self>, to: ClosedRange<Self>) -> Self {
        
        guard from.upperBound != from.lowerBound else {
            return to.lowerBound
        }
        
        let clamped = min(max(self, from.lowerBound), from.upperBound)
        let normalized = (clamped - from.lowerBound) / (from.upperBound - from.lowerBound)
        return normalized * (to.upperBound - to.lowerBound) + to.lowerBound
        /*
        return (clamped - from.lowerBound) / (from.upperBound - from.lowerBound)
        * (to.upperBound - to.lowerBound) + to.lowerBound
        */
    }
}

struct CustomLedView: View {
    @Namespace private var namespace
    
    enum Tool {
        case scribble
        case pencil
        case eraser
    }
    
    private let ledColumns = 64
    private let ledRows = 32
    
    @State private var selectedTool: Tool? = nil
    @State private var penSize: CGFloat = 1.0
    @State private var activeColor: Color = .white
    @State private var showColorPicker = false
    
    @State private var ledStates: [[Color]] = Array(
            repeating: Array(repeating: .black, count: 32),
            count: 64
        )
    
    let x: Double = 5
    //let offset: x.mapped(from: 1...100, to: 5...20)
    
    @State private var isPencilTapped: Bool =  false
    @State private var isEraserTapped: Bool =  false
    @State private var isBinTapped: Bool =  false
    
    
    private var isScribbleSelected: Bool { selectedTool == .scribble }
    private var isPencilSelected: Bool { selectedTool == .pencil }
    private var isEraserSelected: Bool { selectedTool == .eraser }
    
    enum SymbolPhase: CaseIterable {
        case idle, drawingOn, drawingOff
    }
    
    var body: some View {
        ZStack{
            
            MeshGradientView()
                .ignoresSafeArea()
                .saturation(0.4)
            
            VStack{
                GlassEffectContainer(spacing: 40.0) {
                    // When scribble is selected we increase the spacing
                    HStack(spacing: isScribbleSelected ? 40.0 : 20.0) {
                        
                        // MARK: - Scribble + Slider GROUP (Unified singular glass effect)
                        HStack(spacing: 16) {
                            // Slider is on the LEFT, inside same glass card
                            if isPencilSelected {
                                HStack{
                                    Slider(
                                        value: $penSize,
                                        in: 1...100
                                        //step: 1
                                    ) {
                                        Text("Size")
                                    } minimumValueLabel: {
                                        Text("")
                                    } maximumValueLabel: {
                                        Text("\(Int(penSize))")
                                    }
                                    .animation(.easeInOut(duration: 0.1), value: penSize)
                                    .frame(width: 175)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                    //.border(.green)
                                        // Stroke size preview (already in your code)
                                    ColorPicker("", selection: $activeColor, supportsOpacity: false)
                                        .labelsHidden()
                                        .padding()
                                        .frame(
                                            width: penSize.mapped(from: 1...100, to: 10...30),
                                            height: penSize.mapped(from: 1...100, to: 10...30)
                                        )
                                        .onTapGesture {
                                            showColorPicker.toggle()
                                            selectedTool = .pencil    // auto-select pencil when picking colors (optional)
                                        }
                                    /*
                                    Circle()
                                        .fill(activeColor)
                                        .frame(
                                            width: penSize.mapped(from: 1...100, to: 10...30),
                                            height: penSize.mapped(from: 1...100, to: 10...30)
                                        )
                                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                        .onTapGesture {
                                            showColorPicker.toggle()
                                            selectedTool = .pencil    // auto-select pencil when picking colors (optional)
                                        }
                                     */
                                    #if !os(iOS)
                                        .popover(isPresented: $showColorPicker) {   // iPad/Mac / large iPhone in landscape
                                            VStack {
                                                Text("Select Color")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                ColorPicker("", selection: $activeColor, supportsOpacity: false)
                                                    .labelsHidden()
                                                    .padding()

                                                Button("Done") { showColorPicker = false }
                                                    .padding(.bottom)
                                            }
                                            .padding()
                                        }
                                    #endif
                                        .sheet(isPresented: $showColorPicker) {     // iPhone portrait fallback
                                            VStack {
                                                Text("Select Color")
                                                    .font(.headline)
                                                    .padding(.top)

                                                ColorPicker("", selection: $activeColor, supportsOpacity: false)
                                                    .labelsHidden()
                                                    .padding()

                                                Button("Done") { showColorPicker = false }
                                                    .padding(.bottom)
                                            }
                                        }
                                }
                            }
                            
                            // Scribble icon on the RIGHT of the slider
                            Image(systemName: "scribble.variable")
                                .font(.system(size: 27))
                            
                                .phaseAnimator(SymbolPhase.allCases, trigger: isPencilTapped) { content, phase in
                                    content
                                        .symbolEffect(.drawOn, isActive: phase == .drawingOn)
                                        .symbolEffect(.drawOff, isActive: phase == .drawingOff)
                                } animation: { phase in
                                    switch phase {
                                    case .drawingOn: return .bouncy // Duration of first effect
                                    case .drawingOff: return .easeInOut(duration: 1.0) // Duration of second
                                    case .idle: return nil
                                        
                                    }
                                }
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 20)
                        .glassEffect(.regular.interactive())
                        .glassEffectID("scribbleGroup", in: namespace)
                        .glassEffectUnion(id: "scribbleGroup", namespace: namespace)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTool = (selectedTool == .pencil) ? nil : .pencil
                            }
                            isPencilTapped.toggle()
                        }
                        
                        // MARK: - Eraser + conditional trash
                        HStack(spacing: isEraserSelected ? 32.0 : 16.0) {
                            Image(systemName: "eraser.fill")
                                .frame(width: 50.0, height: 50.0)
                                .font(.system(size: 27))
                                .glassEffect()
                                .glassEffectID("eraser", in: namespace)
                                .glassEffectUnion(id: "eraser", namespace: namespace)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedTool = .eraser
                                    }
                                    isEraserTapped.toggle()
                                }
                                .symbolEffect(.wiggle, value: isEraserTapped)
                            //.border(.black)
                            
                            if isEraserSelected {
                                Image(systemName: "xmark.bin")
                                    .frame(width: 50, height: 50)
                                    .font(.system(size: 27))
                                    .glassEffect()
                                    .glassEffectID("trash", in: namespace)
                                    .glassEffectUnion(id: "trash", namespace: namespace)
                                    .onTapGesture {
                                            ledStates = Array(
                                                repeating: Array(repeating: .black, count: ledRows),
                                                count: ledColumns
                                            )
                                            isBinTapped.toggle()
                                        // clear / delete action here
                                        /*
                                        pixels = Array(
                                            repeating: Array(repeating: Color.black, count: ledColumns),
                                            count: ledRows
                                        )
                                         */
                                        isBinTapped.toggle()
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                
                                    .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, value: isBinTapped)
                            }
                        }
                        .glassEffect()
                        .glassEffectID("scribbleGroup", in: namespace)
                        .glassEffectUnion(id: "scribbleGroup", namespace: namespace)
                        //.border(.blue)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTool)
                    /*
                    // Simple color palette + picker
                    let palette: [Color] = [
                        .white, .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink
                    ]

                    HStack(spacing: 12) {
                        ForEach(palette, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(activeColor == color ? 1.0 : 0.0), lineWidth: 2)
                                )
                                .shadow(radius: activeColor == color ? 4 : 0)
                                .onTapGesture {
                                    activeColor = color
                                    // Optionally auto-select pencil when choosing a color:
                                    selectedTool = .pencil
                                }
                        }

                        Divider().frame(height: 24)

                        ColorPicker("", selection: $activeColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    
                    */
                }
                Text("Custom Face views coming soon!")
                
                Spacer()
                // MARK: - LED drawing area
                
                LEDArraySection(
                    ledStates: $ledStates,
                    isErasing: isEraserSelected,
                    brushRadius: Int(penSize.mapped(from: 1...100, to: 0...4)),
                    canDraw: isPencilSelected || isEraserSelected,
                    activeColor: activeColor
                )
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 38))
                    .rotationEffect(.degrees(90))
                    .frame(width: 500)
                
                Spacer()
                
            }
        
        }
    }
}

