import SwiftUI

public extension Image {

    // MARK: - Tab Bar

    static var catalogTab: Image   { DSIcon.catalogTab.image }
    static var searchTab: Image    { DSIcon.searchTab.image }
    static var watchlistTab: Image { DSIcon.watchlistTab.image }

    // MARK: - App Chrome

    static var film: Image      { DSIcon.film.image }
    static var bell: Image      { DSIcon.bell.image }
    static var bellBadge: Image { DSIcon.bellBadge.image }

    // MARK: - Navigation

    static var back: Image         { DSIcon.back.image }
    static var chevronRight: Image { DSIcon.chevronRight.image }
    static var close: Image        { DSIcon.close.image }
    static var more: Image         { DSIcon.more.image }

    // MARK: - Watchlist Actions

    static var addBookmark: Image    { DSIcon.addBookmark.image }
    static var removeBookmark: Image { DSIcon.removeBookmark.image }

    // MARK: - Movie Detail Actions

    static var heartFill: Image { DSIcon.heartFill.image }
    static var heart: Image     { DSIcon.heart.image }
    static var share: Image     { DSIcon.share.image }

    // MARK: - Review & Editing

    static var logReview: Image { DSIcon.logReview.image }
    static var edit: Image      { DSIcon.edit.image }
    static var trash: Image     { DSIcon.trash.image }
    static var checkmark: Image { DSIcon.checkmark.image }

    // MARK: - Toolbar

    static var filter: Image       { DSIcon.filter.image }
    static var filterActive: Image { DSIcon.filterActive.image }
    static var sort: Image         { DSIcon.sort.image }
    static var retry: Image        { DSIcon.retry.image }

    // MARK: - Star Rating

    static var starFilled: Image { DSIcon.starFilled.image }
    static var starHalf: Image   { DSIcon.starHalf.image }
    static var starEmpty: Image  { DSIcon.starEmpty.image }

    // MARK: - Playback

    static var play: Image  { DSIcon.play.image }
    static var pause: Image { DSIcon.pause.image }
    static var stop: Image  { DSIcon.stop.image }

    // MARK: - Social / Reviews

    static var comment: Image { DSIcon.comment.image }

    // MARK: - People

    static var personPlaceholder: Image { DSIcon.personPlaceholder.image }

    // MARK: - State Indicators

    static var errorCircle: Image { DSIcon.errorCircle.image }
    static var infoCircle: Image  { DSIcon.infoCircle.image }
}
