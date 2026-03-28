import SwiftUI

public extension Color {
    /// Creates a `Color` from a hex string.
    ///
    /// Supported formats (with or without a leading `#`):
    /// - 3 digits: `RGB`  → expands to `RRGGBB`
    /// - 6 digits: `RRGGBB`
    /// - 8 digits: `RRGGBBAA`
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch raw.count {
        case 3:
            r = (value >> 8 & 0xF) * 17
            g = (value >> 4 & 0xF) * 17
            b = (value       & 0xF) * 17
            a = 255
        case 6:
            r = value >> 16 & 0xFF
            g = value >>  8 & 0xFF
            b = value        & 0xFF
            a = 255
        case 8:
            r = value >> 24 & 0xFF
            g = value >> 16 & 0xFF
            b = value >>  8 & 0xFF
            a = value        & 0xFF
        default:
            r = 0; g = 0; b = 0; a = 255
        }

        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
