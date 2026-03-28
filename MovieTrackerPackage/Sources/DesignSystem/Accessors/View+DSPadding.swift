import SwiftUI

public extension View {
    /// Applies a uniform design-system padding value to the specified edges.
    ///
    /// ```swift
    /// .padding(.bottom, .cardContent)
    /// .padding(.horizontal, .screenEdge)
    /// ```
    func padding(_ edges: Edge.Set = .all, _ token: DSPadding) -> some View {
        padding(edges, token.value)
    }

    /// Applies the full design-system edge insets for the given token.
    /// Asymmetric tokens (e.g. `.tagInset`, `.screenEdge`) apply correctly.
    ///
    /// ```swift
    /// .padding(.screenEdge)
    /// .padding(.cardContent)
    /// ```
    func padding(_ token: DSPadding) -> some View {
        padding(token.edgeInsets)
    }
}
