import SwiftUI
import WatchKit

struct FacePickerView: View {
    @EnvironmentObject private var model: WatchConnectivityManager
    @AppStorage("wristFlickEnabled") private var wristFlickEnabled = false
    @StateObject private var wristMotion = WristMotionController()

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(SharedOptions.protoActionOptions.enumerated()), id: \.offset) { index, action in
                    let view = index + 1
                    FaceTile(
                        action: action,
                        view: view,
                        isSelected: model.selectedView == view
                    ) {
                        model.selectView(view)
                    }
                    .disabled(!model.canControlController)
                }
            }
            .padding(.horizontal, 4)

            if !model.controllerState.isConnected {
                ContentUnavailableView(
                    "Controller Disconnected",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Connect from the LumiFur dashboard to change faces.")
                )
                .padding(.top, 12)
            }
        }
        .navigationTitle("Faces")
        .onAppear(perform: updateMotionState)
        .onChange(of: wristFlickEnabled) { _, _ in updateMotionState() }
        .onChange(of: model.canControlController) { _, _ in updateMotionState() }
        .onDisappear {
            wristMotion.stop()
        }
    }

    private func updateMotionState() {
        guard wristFlickEnabled, model.canControlController else {
            wristMotion.stop()
            return
        }

        wristMotion.start { direction in
            switch direction {
            case .left:
                model.moveSelectedView(by: 1)
            case .right:
                model.moveSelectedView(by: -1)
            }
        }
    }
}

private struct FaceTile: View {
    let action: SharedOptions.ProtoAction
    let view: Int
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            ZStack(alignment: .topTrailing) {
                face
                    .frame(maxWidth: .infinity, minHeight: 58)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(5)
                }
            }
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Face \(view), \(action.rawValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Selects this face on the LumiFur controller")
    }

    @ViewBuilder
    private var face: some View {
        switch action {
        case .emoji(let value):
            Text(value)
                .font(.system(size: value.count > 3 ? 15 : 28, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(6)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 26, weight: .semibold))
        }
    }
}
