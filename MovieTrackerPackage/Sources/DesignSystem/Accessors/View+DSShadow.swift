import SwiftUI

public extension View {
    /// Applies a design-system shadow token.
    ///
    /// ```swift
    /// .shadow(.card)
    /// .shadow(.elevated)
    /// .shadow(.modal)
    /// ```
    func shadow(_ token: DSShadow) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
