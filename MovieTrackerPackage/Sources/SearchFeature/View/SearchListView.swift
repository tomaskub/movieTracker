import DesignSystem
import DomainModels
import SharedUIComponents
import SwiftUI
import TMDBClient

struct SearchListView: View {
    private let presenter: SearchListPresenter
    private let filterSheetPresenter: SearchFilterSheetPresenter
    private let sortSheetPresenter: SearchSortSheetPresenter
    @Bindable private var router: SearchRouter
    @FocusState private var isSearchFieldFocused: Bool

    init(
        presenter: SearchListPresenter,
        filterSheetPresenter: SearchFilterSheetPresenter,
        sortSheetPresenter: SearchSortSheetPresenter,
        router: SearchRouter
    ) {
        self.presenter = presenter
        self.filterSheetPresenter = filterSheetPresenter
        self.sortSheetPresenter = sortSheetPresenter
        _router = Bindable(router)
    }

    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            VStack(spacing: 0) {
                searchBar
                results
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presenter.openFilterSheet()
                    } label: {
                        Image(systemName: presenter.isFilterActive
                              ? DSIcon.filterActive.rawValue
                              : DSIcon.filter.rawValue)
                    }
                    .disabled(isSheetDisabled)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presenter.openSortSheet()
                    } label: {
                        Image.sort
                    }
                    .disabled(isSheetDisabled)
                }
            }
            .navigationDestination(for: Int.self) { movieId in
                Text("Movie Detail \(movieId)")
            }
            .sheet(isPresented: Binding(
                get: { presenter.isFilterSheetPresented },
                set: { presenter.isFilterSheetPresented = $0 }
            )) {
                SearchFilterSheetView(presenter: filterSheetPresenter)
            }
            .sheet(isPresented: Binding(
                get: { presenter.isSortSheetPresented },
                set: { presenter.isSortSheetPresented = $0 }
            )) {
                SearchSortSheetView(presenter: sortSheetPresenter)
            }
        }
    }

    private var isSheetDisabled: Bool {
        switch presenter.searchState {
        case .idle, .loading:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: DSSpacing.xSmall) {
            TextField("Search movies...", text: Binding(
                get: { presenter.query },
                set: { presenter.query = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .submitLabel(.search)
            .focused($isSearchFieldFocused)
            .onSubmit { presenter.submitSearch() }

            Button("Search") {
                isSearchFieldFocused = false
                presenter.submitSearch()
            }
            .font(.buttonLabel)
            .foregroundStyle(Color.accent)
            .disabled(!presenter.canSubmitSearch)
        }
        .padding(.horizontal, .screenEdge)
        .padding(.vertical, .componentGap)
    }

    @ViewBuilder
    private var results: some View {
        switch presenter.searchState {
        case .idle:
            centeredContent {
                EmptyStateView(title: "Search for a movie", subtitle: "Enter a title above to get started")
            }
        case .loading:
            centeredContent {
                LoadingView()
            }
        case .results(_, let filtered):
            List(filtered) { movie in
                Button {
                    presenter.selectMovie(movieId: movie.id)
                } label: {
                    MovieCardView(
                        title: movie.title,
                        year: movie.releaseYear,
                        rating: movie.voteAverage,
                        imageState: presenter.imageStates[movie.id] ?? .placeholder
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
        case .empty(let reason):
            centeredContent {
                emptyReasonView(reason)
            }
        case .error(let error, _):
            centeredContent {
                ErrorStateView(
                    message: errorMessage(for: error),
                    onRetry: presenter.retrySearch
                )
            }
        }
    }

    @ViewBuilder
    private func emptyReasonView(_ reason: SearchState.EmptyReason) -> some View {
        switch reason {
        case .noMatches:
            EmptyStateView(title: "No movies found", subtitle: "Try a different search term")
        case .filtersEliminated:
            VStack(spacing: .small) {
                EmptyStateView(
                    title: "No results match your active filters",
                    subtitle: "Adjust or clear your filters to see results"
                )
                Button("Clear Filters") {
                    presenter.clearActiveFilters()
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.accent)
            }
        }
    }

    private func errorMessage(for error: TMDBError) -> String {
        switch error {
        case .offline: return "You appear to be offline. Check your connection and try again."
        case .networkFailure: return "Something went wrong. Please try again."
        case .invalidRequest: return "The search request was invalid. Please try again."
        }
    }

    private func centeredContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Movie {
    var releaseYear: Int {
        Int(releaseDate.prefix(4)) ?? 0
    }
}
