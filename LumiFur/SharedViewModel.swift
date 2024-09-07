//
//  SharedViewModel.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 06/09/2024.
//

import Foundation
import SwiftUI

class SharedViewModel: ObservableObject {
    @Published var protogenImage: Image? = Image("Protogen") // Your Protogen image
        
        .resizable()
        .interpolation(.high)
        .antialiased(true)
}
