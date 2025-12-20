struct LEDPreview: View {
    // Your 64×32 LED state
    @State private var ledStates: [[Color]] = Array(
        repeating: Array(repeating: .black, count: 32),
        count: 64
    )

    // Snapshot image, updated only when ledStates changes
    @State private var snapshot: Image?

    var body: some View {
        Group {
            if let snapshot {
                snapshot
                    .resizable()
                    .aspectRatio(64 / 32, contentMode: .fit)
            } else {
                // placeholder while first snapshot is generated
                Color.white
                    .aspectRatio(64 / 32, contentMode: .fit)
            }
        }
        .onAppear { updateSnapshot() }
        // whenever ledStates changes, re‑rasterize
        .onChange(of: ledStates) { oldStates, newStates in
            updateSnapshot()
        }
        .padding(10)
    }

    private func updateSnapshot() {
        // Render into a tiny 64×32 bitmap
        let width = 64
        let height = 32
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height)
        )
        let uiImage = renderer.image { ctx in
            for x in 0..<width {
                for y in 0..<height {
                    ctx.cgContext.setFillColor(UIColor(ledStates[x][y]).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        snapshot = Image(uiImage: uiImage).renderingMode(.original)
    }
}