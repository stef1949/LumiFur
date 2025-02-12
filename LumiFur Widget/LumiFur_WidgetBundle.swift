//
//  LumiFur_WidgetBundle.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//

import WidgetKit
import SwiftUI

@main
struct LumiFur_WidgetBundle: WidgetBundle {
    var body: some Widget {
        LumiFur_Widget()
        LumiFur_WidgetControl()
        LumiFur_WidgetLiveActivity()
    }
}
