import SwiftUI

#Preview("MovieCardView – placeholder") {
    MovieCardView(
        title: "Dune: Part Two",
        year: 2024,
        rating: 8.3,
        imageState: .placeholder
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
}

#Preview("MovieCardView – image") {
    MovieCardView(
        title: "Oppenheimer",
        year: 2023,
        rating: 8.5,
        imageState: .image(Image(systemName: "photo"))
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
}

#Preview("ErrorStateView") {
    ErrorStateView(message: "Could not load movies. Check your connection.") {}
}

#Preview("InlineErrorView") {
    InlineErrorView(message: "Cast unavailable")
        .padding()
}

#Preview("EmptyStateView – title only") {
    EmptyStateView(title: "Your watchlist is empty")
}

#Preview("EmptyStateView – title + subtitle") {
    EmptyStateView(
        title: "No results",
        subtitle: "Try a different search term"
    )
}

#Preview("LoadingView") {
    LoadingView()
}
