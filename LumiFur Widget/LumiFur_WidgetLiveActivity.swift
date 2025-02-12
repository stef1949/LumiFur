//
//  LumiFur_WidgetLiveActivity.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LumiFur_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var connectionStatus: String
        var signalStrength: Int
        //var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LumiFur_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LumiFur_WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("LumiFur")
                    Image(systemName:"aqi.medium")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                    
                    //Image cannot exceed 4kb
                    //Image("Protogen")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                    // more content
                }
            } compactLeading: {
                Text("LumiFur")
                //Image("Protogen")
            } compactTrailing: {
                //Text("T")
                Image("bluetooth.fill")
            } minimal: {
                Text("m")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
}

extension LumiFur_WidgetAttributes {
    fileprivate static var preview: LumiFur_WidgetAttributes {
        LumiFur_WidgetAttributes(name: "World")
    }
}

extension LumiFur_WidgetAttributes.ContentState {
    fileprivate static var smiley: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 75)
    }
    
    fileprivate static var starEyes: LumiFur_WidgetAttributes.ContentState {
        LumiFur_WidgetAttributes.ContentState(connectionStatus: "Connected", signalStrength: 80)
    }
}

#Preview("Notification", as: .content, using: LumiFur_WidgetAttributes.preview) {
   LumiFur_WidgetLiveActivity()
} contentStates: {
    LumiFur_WidgetAttributes.ContentState.smiley
    LumiFur_WidgetAttributes.ContentState.starEyes
}
