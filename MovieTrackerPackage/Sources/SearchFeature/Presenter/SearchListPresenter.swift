import DomainModels
import Observation
import SharedUIComponents
import SwiftUI
import TMDBClient
import UIKit

@Observable
@MainActor
final class SearchListPresenter {
    var query: String = ""
    var searchState: SearchState = .idle
    var activeFilters: SearchFilterState = SearchFilterState()
    var activeSort: SearchSortOption = .releaseDate
    var imageStates: [Int: MovieCardView.ImageState] = [:]
    var isFilterSheetPresented: Bool = false
    var isSortSheetPresented: Bool = false

    var isFilterActive: Bool { !activeFilters.isDefault }
    var canSubmitSearch: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private let interactor: any SearchListInteractorProtocol
    weak var router: (any SearchRouterProtocol)?

    var onOpenFilterSheet: ((SearchFilterState) -> Void)?
    var onOpenSortSheet: ((SearchSortOption) -> Void)?

    private var lastSubmittedQuery: String?
    private var allMovies: [Movie] = []

    nonisolated(unsafe) var searchTask: Task<Void, Never>?
    nonisolated(unsafe) var posterTasks: [Int: Task<Void, Never>] = [:]

    init(interactor: any SearchListInteractorProtocol) {
        self.interactor = interactor
    }

    func submitSearch() {
        guard canSubmitSearch else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        lastSubmittedQuery = trimmed
        startSearch(query: trimmed)
    }

    func retrySearch() {
        guard let query = lastSubmittedQuery else { return }
        startSearch(query: query)
    }

    func selectMovie(movieId: Int) {
        router?.pushMovieDetail(movieId: movieId)
    }

    func openFilterSheet() {
        switch searchState {
        case .idle, .loading:
            return
        default:
            break
        }
        onOpenFilterSheet?(activeFilters)
        isFilterSheetPresented = true
    }

    func openSortSheet() {
        switch searchState {
        case .idle, .loading:
            return
        default:
            break
        }
        onOpenSortSheet?(activeSort)
        isSortSheetPresented = true
    }

    func commitFilters(_ newFilters: SearchFilterState) {
        activeFilters = newFilters
        recomputeFilteredResults()
    }

    func commitSort(_ newSort: SearchSortOption) {
        activeSort = newSort
        recomputeFilteredResults()
    }

    func clearActiveFilters() {
        activeFilters = SearchFilterState()
        recomputeFilteredResults()
    }

    private func startSearch(query: String) {
        searchTask?.cancel()
        searchTask = nil
        posterTasks.values.forEach { $0.cancel() }
        posterTasks = [:]
        imageStates = [:]
        allMovies = []

        searchState = .loading(query: query)

        searchTask = Task { [weak self] in
            guard let self else { return }
            do throws(TMDBError) {
                let movies = try await self.interactor.searchMovies(query: query)
                guard !Task.isCancelled else { return }
                if movies.isEmpty {
                    self.searchState = .empty(reason: .noMatches)
                } else {
                    self.allMovies = movies
                    self.recomputeFilteredResults()
                    self.startPosterLoads(movies: movies)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.searchState = .error(error, query: query)
            }
        }
    }

    private func recomputeFilteredResults() {
        guard !allMovies.isEmpty else { return }

        var filtered = allMovies

        if !activeFilters.selectedGenreIds.isEmpty {
            filtered = filtered.filter { movie in
                movie.genreIds.contains(where: { activeFilters.selectedGenreIds.contains($0) })
            }
        }

        if activeFilters.minimumRatingEnabled {
            filtered = filtered.filter { Int($0.voteAverage.rounded()) >= activeFilters.minimumRating }
        }

        if !activeFilters.fromYear.isEmpty, let from = Int(activeFilters.fromYear) {
            filtered = filtered.filter { ($0.releaseYear ?? 0) >= from }
        }

        if !activeFilters.toYear.isEmpty, let to = Int(activeFilters.toYear) {
            filtered = filtered.filter { ($0.releaseYear ?? Int.max) <= to }
        }

        switch activeSort {
        case .releaseDate:
            filtered.sort { $0.releaseDate > $1.releaseDate }
        case .title:
            filtered.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .voteAverage:
            filtered.sort { $0.voteAverage > $1.voteAverage }
        }

        if filtered.isEmpty {
            searchState = .empty(reason: .filtersEliminated)
        } else {
            searchState = .results(all: allMovies, filtered: filtered)
        }
    }

    private func startPosterLoads(movies: [Movie]) {
        for movie in movies {
            guard let posterPath = movie.posterPath else { continue }
            imageStates[movie.id] = .placeholder
            posterTasks[movie.id] = Task { [weak self] in
                guard let self else { return }
                guard let data = try? await self.interactor.fetchPosterData(posterPath: posterPath) else { return }
                guard !Task.isCancelled else { return }
                guard let uiImage = UIImage(data: data) else { return }
                self.imageStates[movie.id] = .image(Image(uiImage: uiImage))
            }
        }
    }

    deinit {
        searchTask?.cancel()
        posterTasks.values.forEach { $0.cancel() }
    }
}

private extension Movie {
    var releaseYear: Int? {
        Int(releaseDate.prefix(4))
    }
}
