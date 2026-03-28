import SwiftUI

public struct DSShadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

public extension DSShadow {
    /// Subtle lift for list cards and poster images
    static let card = DSShadow(
        color: .black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 2
    )
    /// Elevated surfaces such as sticky headers or floating controls
    static let elevated = DSShadow(
        color: .black.opacity(0.14),
        radius: 16,
        x: 0,
        y: 4
    )
    /// Modal sheets and overlays
    static let modal = DSShadow(
        color: .black.opacity(0.20),
        radius: 24,
        x: 0,
        y: 8
    )
}
