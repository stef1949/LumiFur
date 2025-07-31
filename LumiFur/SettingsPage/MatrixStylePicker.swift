//
//  MatrixStylePicker.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 7/4/25.
//
import SwiftUI

struct MatrixStylePicker: View {
    @Binding var selectedMatrix: MatrixStyle
    
    var body: some View {
        // --- OPTIMIZATION 2: Explicit Layout Container ---
        // Using an explicit VStack makes the layout intent clear and allows
        // for easy customization of alignment and spacing.
        VStack(alignment: .leading, spacing: 8) {
            Picker("Matrix Style", selection: $selectedMatrix) {
                // The ForEach loop is already efficient.
                ForEach(MatrixStyle.allCases) { style in
                    Text(style.rawValue.capitalized)
                        .tag(style) // Tagging with the enum case itself is correct.
                }
            }
            .pickerStyle(.segmented)
            
            // --- OPTIMIZATION 3: More Robust Status Text ---
            // A small enhancement to add context and improve layout consistency.
            HStack {
                Spacer()
                Text("Current style: \(selectedMatrix.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

struct MatrixStylePicker_Previews: PreviewProvider {
    // A state variable is needed to host the binding for the preview.
    @State private static var previewMatrixStyle: MatrixStyle = .array
    
    static var previews: some View {
        MatrixStylePicker(selectedMatrix: $previewMatrixStyle)
            .padding()
    }
}
