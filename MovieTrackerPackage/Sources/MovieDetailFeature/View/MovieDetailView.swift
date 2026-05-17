import DesignSystem
import DomainModels
import SharedUIComponents
import SwiftUI
import TMDBClient

struct MovieDetailView: View {
    @Bindable private var presenter: MovieDetailPresenter
    @Bindable private var router: MovieDetailRouter

    init(presenter: MovieDetailPresenter, router: MovieDetailRouter) {
        _presenter = Bindable(presenter)
        _router = Bindable(router)
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .onAppear { presenter.handleAppear() }
            .fullScreenCover(item: $router.wizardPresentation) { mode in
                router.makeWizardView(movieId: presenter.movieId, mode: mode)
                    .onDisappear { presenter.handleWizardDismissed() }
            }
            .confirmationDialog(
                "Are you sure you want to delete the review?",
                isPresented: $presenter.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    presenter.handleDeleteReviewConfirmed()
                }
                .accessibilityIdentifier("deleteReviewConfirmButton")
                Button("Cancel", role: .cancel) {
                    presenter.handleDeleteReviewCancelled()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.detailState {
        case .loading:
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let movieDetail):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: .medium) {
                    posterSection(for: movieDetail)
                    detailSection(for: movieDetail)
                    castSection
                    watchlistCTASection(for: movieDetail)
                    reviewSection(for: movieDetail)
                }
            }
        case .error(let error):
            ErrorStateView(
                message: errorMessage(for: error),
                onRetry: presenter.handleRetryDetail
            )
            .accessibilityIdentifier("detailRetryButton")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var navigationTitle: String {
        if case .loaded(let movieDetail) = presenter.detailState {
            return movieDetail.movie.title
        }
        return ""
    }

    @ViewBuilder
    private func posterSection(for movieDetail: MovieDetail) -> some View {
        GeometryReader { geometry in
            AsyncImage(url: tmdbPosterURL(from: movieDetail.movie.posterPath, size: .full)) { phase in
                switch phase {
                case .empty:
                    posterPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipped()
                case .failure:
                    posterPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
            .frame(width: geometry.size.width, height: 300)
            .clipped()
        }
        .frame(height: 300)
        .accessibilityElement()
        .accessibilityLabel(movieDetail.movie.posterPath != nil
            ? "\(movieDetail.movie.title) poster"
            : "No poster available")
        .accessibilityIdentifier("movieDetailPoster")
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.backgroundTertiary)
            .overlay {
                Image.film
                    .font(.system(size: 48))
                    .foregroundStyle(Color.labelOnDark.opacity(0.4))
            }
    }

    @ViewBuilder
    private func detailSection(for movieDetail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: .small) {
            Text(movieDetail.movie.title)
                .font(.heading2)
                .foregroundStyle(.primary)

            HStack(spacing: .xSmall) {
                if !movieDetail.movie.releaseDate.isEmpty {
                    Text(String(movieDetail.movie.releaseDate.prefix(4)))
                        .font(.small)
                        .foregroundStyle(.secondary)
                }
                if movieDetail.movie.voteAverage > 0 {
                    Text("★ \(String(format: "%.1f", movieDetail.movie.voteAverage))")
                        .font(.small)
                        .foregroundStyle(Color.rating)
                }
            }

            if !movieDetail.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .xSmall) {
                        ForEach(movieDetail.genres) { genre in
                            Text(genre.name)
                                .font(.tagLabel)
                                .padding(.tagInset)
                                .background(Color.backgroundTertiary)
                                .cornerRadius(.small)
                        }
                    }
                }
            }

            if !movieDetail.movie.overview.isEmpty {
                Text(movieDetail.movie.overview)
                    .font(.dsBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, .screenEdge)
    }

    @ViewBuilder
    private var castSection: some View {
        VStack(alignment: .leading, spacing: .small) {
            Text("Cast")
                .font(.heading3)
                .padding(.horizontal, .screenEdge)

            switch presenter.castState {
            case .loading:
                LoadingView()
                    .frame(maxWidth: .infinity)
            case .loaded(let castMembers):
                VStack(alignment: .leading, spacing: .xSmall) {
                    ForEach(castMembers.prefix(3), id: \.name) { member in
                        HStack(spacing: .xSmall) {
                            Image.personPlaceholder
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.small)
                                    .foregroundStyle(.primary)
                                Text(member.character)
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, .screenEdge)
                    }
                }
            case .unavailable:
                VStack(alignment: .leading, spacing: .xSmall) {
                    Text("Cast unavailable")
                        .font(.small)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, .screenEdge)
                    Button("Retry loading cast") {
                        presenter.handleRetryCast()
                    }
                    .font(.buttonLabel)
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, .screenEdge)
                    .accessibilityIdentifier("castRetryButton")
                    .accessibilityLabel("Retry loading cast")
                }
            }
        }
    }

    @ViewBuilder
    private func watchlistCTASection(for movieDetail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            Divider()
                .padding(.horizontal, .screenEdge)

            switch presenter.watchlistState {
            case .loading:
                Button("Add to Watchlist") {}
                    .font(.buttonLabel)
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, .screenEdge)
                    .disabled(true)
                    .accessibilityIdentifier("watchlistCTAButton")

            case .onWatchlist:
                Button("Remove from Watchlist") {
                    presenter.handleToggleWatchlist()
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.error)
                .padding(.horizontal, .screenEdge)
                .accessibilityIdentifier("watchlistCTAButton")
                .accessibilityLabel("Remove \(movieDetail.movie.title) from Watchlist")

            case .notOnWatchlist:
                Button("Add to Watchlist") {
                    presenter.handleToggleWatchlist()
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, .screenEdge)
                .accessibilityIdentifier("watchlistCTAButton")
                .accessibilityLabel("Add \(movieDetail.movie.title) to Watchlist")

            case .mutating:
                ProgressView()
                    .tint(.accent)
                    .padding(.horizontal, .screenEdge)
                    .accessibilityIdentifier("watchlistMutatingSpinner")
                    .accessibilityLabel("Updating watchlist")

            case .error(let message):
                Button(presenter.watchlistState == .onWatchlist ? "Remove from Watchlist" : "Add to Watchlist") {
                    presenter.handleToggleWatchlist()
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, .screenEdge)
                .accessibilityIdentifier("watchlistCTAButton")

                Text(message)
                    .font(.dsCaption)
                    .foregroundStyle(Color.error)
                    .padding(.horizontal, .screenEdge)
            }
        }
    }

    @ViewBuilder
    private func reviewSection(for movieDetail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: .small) {
            Divider()
                .padding(.horizontal, .screenEdge)

            Text("Your Review")
                .font(.heading3)
                .padding(.horizontal, .screenEdge)

            switch presenter.reviewState {
            case .loading:
                LoadingView()
                    .frame(maxWidth: .infinity)

            case .noReview:
                Button("Log a Review") {
                    presenter.handleLogReview()
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, .screenEdge)
                .accessibilityIdentifier("logReviewButton")
                .accessibilityLabel("Log a Review for \(movieDetail.movie.title)")

            case .hasReview(let review):
                VStack(alignment: .leading, spacing: .small) {
                    starRatingView(rating: review.rating)

                    if !review.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: .xSmall) {
                                ForEach(review.tags, id: \.self) { tag in
                                    Text(tag.rawValue)
                                        .font(.tagLabel)
                                        .padding(.tagInset)
                                        .background(Color.accentSubtle)
                                        .cornerRadius(.small)
                                }
                            }
                            .padding(.horizontal, .screenEdge)
                        }
                    }

                    if !review.notes.isEmpty {
                        Text(review.notes)
                            .font(.dsBody)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, .screenEdge)
                    }

                    HStack(spacing: .medium) {
                        Button("Edit Review") {
                            presenter.handleEditReview()
                        }
                        .font(.buttonLabel)
                        .foregroundStyle(Color.accent)
                        .accessibilityIdentifier("editReviewButton")
                        .accessibilityLabel("Edit your review of \(movieDetail.movie.title)")

                        Button("Delete Review", role: .destructive) {
                            presenter.handleDeleteReviewTapped()
                        }
                        .font(.buttonLabel)
                        .accessibilityIdentifier("deleteReviewButton")
                        .accessibilityLabel("Delete your review of \(movieDetail.movie.title)")
                    }
                    .padding(.horizontal, .screenEdge)
                }

            case .error(let message):
                Text(message)
                    .font(.dsCaption)
                    .foregroundStyle(Color.error)
                    .padding(.horizontal, .screenEdge)
            }
        }
        .padding(.bottom, .sectionVertical)
    }

    private func starRatingView(rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? DSIcon.starFilled.rawValue : DSIcon.starEmpty.rawValue)
                    .foregroundStyle(Color.rating)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, .screenEdge)
        .accessibilityElement()
        .accessibilityLabel("\(rating) out of 5 stars")
        .accessibilityIdentifier("starRatingDisplay")
    }

    private func errorMessage(for error: TMDBError) -> String {
        switch error {
        case .offline: return "You appear to be offline. Check your connection and try again."
        case .networkFailure: return "Something went wrong loading the movie. Please try again."
        case .invalidRequest: return "The request was invalid. Please try again."
        }
    }
}

private func tmdbPosterURL(from posterPath: String?, size: PosterSize) -> URL? {
    guard let posterPath else { return nil }
    return URL(string: "https://image.tmdb.org/t/p/\(size.pathSegment)\(posterPath)")
}
