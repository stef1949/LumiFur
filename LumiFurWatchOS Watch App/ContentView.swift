import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            WatchDashboardView()
                .navigationDestination(for: WatchDestination.self) { destination in
                    switch destination {
                    case .faces:
                        FacePickerView()
                    case .status:
                        WatchStatusView()
                    case .settings:
                        WatchSettingsView()
                    }
                }
        }
        .alert(
            "Unable to Complete Action",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { model.clearError() }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.clearError()
            }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
