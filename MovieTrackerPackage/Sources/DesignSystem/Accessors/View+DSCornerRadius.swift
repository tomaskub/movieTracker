import SwiftUI

public extension View {
    /// Clips the view to a rounded rectangle using a design-system corner radius token.
    ///
    /// ```swift
    /// .cornerRadius(.medium)
    /// .cornerRadius(.full)
    /// ```
    func cornerRadius(_ radius: DSCornerRadius, style: RoundedCornerStyle = .continuous) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius.rawValue, style: style))
    }
}
