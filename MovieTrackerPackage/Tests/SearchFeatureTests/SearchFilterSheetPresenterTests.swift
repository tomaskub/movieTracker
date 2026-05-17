import DomainModels
import Testing
import TMDBClient
@testable import SearchFeature

@MainActor
struct SearchFilterSheetPresenterTests {

    private func makePresenter(
        behavior: SpySearchFilterSheetInteractor.Behavior = .success(SearchFixtures.genres),
        onConfirm: @escaping (SearchFilterState) -> Void = { _ in }
    ) -> (SearchFilterSheetPresenter, SpySearchFilterSheetInteractor) {
        let interactor = SpySearchFilterSheetInteractor(behavior: behavior)
        let presenter = SearchFilterSheetPresenter(interactor: interactor, onConfirm: onConfirm)
        return (presenter, interactor)
    }

    // MARK: - Genre loading

    @Test func viewAppeared_triggersGenreFetch() async {
        let (presenter, interactor) = makePresenter()
        presenter.viewAppeared()
        await presenter.genreTask?.value
        #expect(interactor.fetchCallCount == 1)
    }

    @Test func viewAppeared_success_setsLoadedState() async {
        let (presenter, _) = makePresenter()
        presenter.viewAppeared()
        await presenter.genreTask?.value
        if case .loaded(let genres) = presenter.genreLoadState {
            #expect(genres.count == SearchFixtures.genres.count)
        } else {
            Issue.record("Expected .loaded")
        }
    }

    @Test func viewAppeared_failure_setsErrorState() async {
        let (presenter, _) = makePresenter(behavior: .failure(.networkFailure))
        presenter.viewAppeared()
        await presenter.genreTask?.value
        if case .error = presenter.genreLoadState {
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test func retryGenreFetch_callsFetchWithForceTrue() async {
        let (presenter, interactor) = makePresenter(behavior: .failure(.networkFailure))
        presenter.viewAppeared()
        await presenter.genreTask?.value
        interactor.behavior = .success(SearchFixtures.genres)
        presenter.retryGenreFetch()
        await presenter.genreTask?.value
        #expect(interactor.lastForce == true)
        #expect(interactor.fetchCallCount == 2)
    }

    // MARK: - Year validation

    @Test func updateFromYear_belowBound_setsError() {
        let (presenter, _) = makePresenter()
        presenter.updateFromYear("1800")
        #expect(presenter.fromYearError != nil)
    }

    @Test func updateFromYear_aboveCurrentYear_setsError() {
        let (presenter, _) = makePresenter()
        presenter.updateFromYear("2999")
        #expect(presenter.fromYearError != nil)
    }

    @Test func updateFromYear_atLowerBound_noError() {
        let (presenter, _) = makePresenter()
        presenter.updateFromYear("1900")
        #expect(presenter.fromYearError == nil)
    }

    @Test func updateYears_fromGreaterThanTo_setsRangeError() {
        let (presenter, _) = makePresenter()
        presenter.updateFromYear("2022")
        presenter.updateToYear("2010")
        #expect(presenter.yearRangeError != nil)
    }

    @Test func updateYears_fromEqualToTo_noRangeError() {
        let (presenter, _) = makePresenter()
        presenter.updateFromYear("2015")
        presenter.updateToYear("2015")
        #expect(presenter.yearRangeError == nil)
    }

    // MARK: - Clear and confirm

    @Test func clearAllFilters_resetsState() {
        let (presenter, _) = makePresenter()
        presenter.draftFilters.selectedGenreIds = [28]
        presenter.updateFromYear("1800")
        presenter.clearAllFilters()
        #expect(presenter.draftFilters == SearchFilterState())
        #expect(presenter.fromYearError == nil)
        #expect(presenter.toYearError == nil)
        #expect(presenter.yearRangeError == nil)
    }

    @Test func confirm_callsOnConfirmWithCurrentDraft() {
        var received: SearchFilterState?
        let (presenter, _) = makePresenter(onConfirm: { received = $0 })
        presenter.draftFilters.selectedGenreIds = [28, 878]
        presenter.confirm()
        #expect(received?.selectedGenreIds == [28, 878])
    }
}

// MARK: - Spy

final class SpySearchFilterSheetInteractor: SearchFilterSheetInteractorProtocol {
    enum Behavior {
        case success([Genre])
        case failure(TMDBError)
        case loading
    }

    var behavior: Behavior
    private(set) var fetchCallCount = 0
    private(set) var lastForce: Bool?

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] {
        fetchCallCount += 1
        lastForce = force
        switch behavior {
        case .success(let genres): return genres
        case .failure(let error): throw error
        case .loading:
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return []
        }
    }
}
