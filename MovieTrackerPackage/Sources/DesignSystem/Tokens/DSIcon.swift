import SwiftUI

public enum DSIcon: String, CaseIterable, Sendable {

    // MARK: - Tab Bar
    case catalogTab   = "popcorn"
    case searchTab    = "magnifyingglass"
    case watchlistTab = "bookmark"

    // MARK: - App Chrome
    /// Film reel — app logo mark and poster placeholder
    case film         = "film"
    /// Notification bell shown in the main nav bar
    case bell         = "bell"
    /// Bell with an active notification badge
    case bellBadge    = "bell.badge"

    // MARK: - Navigation
    case back         = "arrow.backward"
    case chevronRight = "chevron.right"
    case close        = "xmark"
    case more         = "ellipsis"

    // MARK: - Watchlist Actions
    case addBookmark    = "bookmark.badge.plus"
    case removeBookmark = "bookmark.slash"

    // MARK: - Movie Detail Actions
    /// Favourite / heart shown in the detail nav bar
    case heartFill    = "heart.fill"
    case heart        = "heart"
    /// Share sheet trigger shown in the detail nav bar
    case share        = "square.and.arrow.up"

    // MARK: - Review & Editing
    case logReview    = "square.and.pencil"
    case edit         = "pencil"
    case trash        = "trash"
    case checkmark    = "checkmark.circle.fill"

    // MARK: - Toolbar
    case filter       = "line.3.horizontal.decrease.circle"
    case filterActive = "line.3.horizontal.decrease.circle.fill"
    case sort         = "arrow.up.arrow.down"
    case retry        = "arrow.clockwise"

    // MARK: - Star Rating
    case starFilled   = "star.fill"
    case starHalf     = "star.leadinghalf.filled"
    case starEmpty    = "star"

    // MARK: - Playback (icon buttons in mockup)
    case play         = "play.fill"
    case pause        = "pause.fill"
    case stop         = "stop.fill"

    // MARK: - Social / Reviews
    /// Comment count on a review card
    case comment      = "bubble.right"

    // MARK: - People
    /// Cast member profile image placeholder
    case personPlaceholder = "person.crop.circle.fill"

    // MARK: - State Indicators
    case errorCircle  = "exclamationmark.circle"
    case infoCircle   = "info.circle"
}

public extension DSIcon {
    var image: Image {
        Image(systemName: rawValue)
    }
}
