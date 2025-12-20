import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LEDPreviewModel: ObservableObject {
    // Shared 64×32 LED state
    @Published var ledStates: [[Color]] = Array(
        repeating: Array(repeating: .black, count: 32),
        count: 64
    )

    // Cached snapshot (so multiple views don’t re-render independently)
    @Published private(set) var snapshot: Image?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-render only when ledStates changes (and collapse bursts into one frame)
        $ledStates
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)

        updateSnapshot()
    }

    func updateSnapshot() {
        #if canImport(UIKit)
        let width = 64
        let height = 32

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let uiImage = renderer.image { ctx in
            for x in 0..<width {
                for y in 0..<height {
                    ctx.cgContext.setFillColor(UIColor(ledStates[x][y]).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        snapshot = Image(uiImage: uiImage).renderingMode(.original)
        #endif
    }
}