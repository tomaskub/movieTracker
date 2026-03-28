import SwiftUI

public extension Font {

    // MARK: - Primary Scale

    static var heading1: Font    { DSFonts.heading1 }
    static var heading2: Font    { DSFonts.heading2 }
    static var heading3: Font    { DSFonts.heading3 }
    /// Design system body — use instead of `.body` to avoid shadowing the system font.
    static var dsBody: Font      { DSFonts.body }
    static var small: Font       { DSFonts.small }
    /// Design system caption — use instead of `.caption` to avoid shadowing the system font.
    static var dsCaption: Font   { DSFonts.caption }

    // MARK: - Supporting Scale

    static var buttonLabel: Font { DSFonts.buttonLabel }
    static var tagLabel: Font    { DSFonts.tagLabel }
}
