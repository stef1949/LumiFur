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

// MARK: – Home‑screen Widget

struct LumiFurHomeWidget: Widget {
    let kind = SharedDataKeys.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomeProvider()) { entry in
            HomeWidgetView(state: entry.state)
        }
        .configurationDisplayName("LumiFur Home Widget")
        .description("Controls and status for your LumiFur device.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct HomeEntry: TimelineEntry {
    let date: Date = .now
    let state = LumiFur_WidgetAttributes.ContentState.smiley
}

struct HomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeEntry { HomeEntry() }
    func getSnapshot(in context: Context, completion: @escaping (HomeEntry) -> Void) {
        completion(HomeEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeEntry>) -> Void) {
        completion(.init(entries: [HomeEntry()], policy: .never))
    }
}

struct HomeWidgetView: View {
    let state: LumiFur_WidgetAttributes.ContentState
    var body: some View {
        VStack {
            Text("LumiFur").font(.headline)
            Text("View: \(state.selectedView)").font(.subheadline)
        }
        .padding()
    }
}
