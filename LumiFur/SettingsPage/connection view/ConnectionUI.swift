import SwiftUI

// MARK: - Shared Connection UI Styles

private enum ConnectionUI {
    static let cardCorner: CGFloat = 20
    static let rowCorner: CGFloat  = 18
    static let cardPadding: CGFloat = 14
    static let rowPadding: CGFloat  = 14
}

private struct ConnectionCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(ConnectionUI.cardPadding)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ConnectionUI.cardCorner, style: .continuous))
    }
}

private struct ConnectionRow: ViewModifier {
    let interactive: Bool
    func body(content: Content) -> some View {
        if interactive {
            content
                .padding(ConnectionUI.rowPadding)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ConnectionUI.rowCorner, style: .continuous))
        } else {
            content
                .padding(ConnectionUI.rowPadding)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ConnectionUI.rowCorner, style: .continuous))
        }
    }
}

private extension View {
    func connectionCard() -> some View { modifier(ConnectionCard()) }
    func connectionRow(interactive: Bool = true) -> some View { modifier(ConnectionRow(interactive: interactive)) }
}