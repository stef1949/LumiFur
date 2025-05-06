//
//  AppIntent.swift
//  LumiFur Widget
//
//  Created by Stephan Ritchie on 2/12/25.
//

import WidgetKit
import AppIntents
import Foundation // Needed for Notification.Name

// Define the intent for changing the view
struct ChangeLumiFurViewIntent: AppIntent {
    // Title shown potentially in shortcuts, etc.
    static let title: LocalizedStringResource = "Change LumiFur View"
    // How the intent is described
    static let description = IntentDescription("Changes the currently displayed view on the LumiFur device.")

    // Optional: Parameters if the intent needed input (e.g., specific view number)
    // @Parameter(title: "View Number")
    // var viewNumber: Int?

    // The action performed when the widget button is tapped
    @MainActor // Ensure UI updates happen on main thread if needed
    func perform() async throws -> some IntentResult {
        print("ChangeLumiFurViewIntent: Perform triggered!")

        // --- Access Shared Data ---
        guard let defaults = UserDefaults(suiteName: SharedDataKeys.suiteName) else {
            print("Intent Error: Could not access shared UserDefaults suite.")
            // Decide how to handle error - maybe throw custom error
            // For now, just return failure or do nothing
             return .result() // Indicate success but maybe no value needed back
        }

        let currentView = defaults.integer(forKey: SharedDataKeys.selectedView)
        // Use a sensible default if key doesn't exist yet
        let currentViewOrDefault = defaults.object(forKey: SharedDataKeys.selectedView) == nil ? 1 : currentView

        // --- Calculate Next View (Example Logic) ---
        // Assuming 12 views max, cycle from 12 back to 1
        var nextView = currentViewOrDefault + 1
        if nextView > 12 { // Replace 12 with your actual max view count
            nextView = 1
        }
        print("Intent: Current view \(currentViewOrDefault), calculated next view \(nextView)")


        // --- !!! Critical Interation with App Logic !!! ---
        // Option A: Directly access a shared instance (if AccessoryViewModel is designed as a singleton - less common)
        // AccessoryViewModel.shared.setView(nextView)
        // Option B: Post a Notification that AccessoryViewModel listens for
         NotificationCenter.default.post(name: .changeViewIntentTriggered, object: nil, userInfo: ["nextView": nextView])
        // Option C: Use background tasks or other mechanisms if AccessoryViewModel isn't readily available.

        // --- Update Shared State (Crucial!) ---
        // Write the *new* view back to UserDefaults so the widget updates
        defaults.set(nextView, forKey: SharedDataKeys.selectedView)
        print("Intent: Wrote next view \(nextView) to shared defaults.")

        // --- Trigger Widget Reload ---
        // Although the main app might also trigger this when setView completes,
        // doing it here ensures the widget tries to update sooner.
        WidgetCenter.shared.reloadTimelines(ofKind: SharedDataKeys.widgetKind)

        // Indicate success
        return .result()
    }
}

// Optional: Define Notification Name if using Option B
extension Notification.Name {
     static let changeViewIntentTriggered = Notification.Name("com.richies3d.LumiFur.ChangeViewIntentTriggered")
}
