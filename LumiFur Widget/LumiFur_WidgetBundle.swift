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
    @WidgetBundleBuilder
    var body: some Widget {
        LumiFur_Widget()
        LumiFur_WidgetControl()
        LumiFur_WidgetLiveActivity()
    }
}
