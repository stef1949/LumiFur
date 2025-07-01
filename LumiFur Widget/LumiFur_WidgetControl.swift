//
//  LumiFur_WidgetControl.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//  Copyright © (Richies3D Ltd). All rights reserved.
//
//


import SwiftUI
import WidgetKit
import AppIntents



/// Control widget to cycle the LumiFur display view
struct LumiFur_WidgetControl: ControlWidget {
     let kind = SharedDataKeys.widgetKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: kind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: ChangeLumiFurViewIntent()) {
                Label("View: \(value.selectedView)", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .displayName("Change LumiFur View")
        .description("Advance to the next display view on your LumiFur device.")
    }
}

extension LumiFur_WidgetControl {
    struct ViewValue: Codable, Equatable {
        var selectedView: Int
    }

    struct Provider: ControlValueProvider {
           typealias Value = ViewValue

           var previewValue: ViewValue { .init(selectedView: 1) }

           func currentValue() async throws -> ViewValue {
               let view = UserDefaults(suiteName: SharedDataKeys.suiteName)?
                   .integer(forKey: SharedDataKeys.selectedView) ?? 1
               return .init(selectedView: view)
           }
       }
   }
