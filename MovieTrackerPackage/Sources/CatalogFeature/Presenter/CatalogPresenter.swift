import Observation
import SharedUIComponents
import SwiftUI
import TMDBClient
import UIKit

@Observable
@MainActor
final class CatalogPresenter {
    var phase: CatalogPhase = .idle
    var imageStates: [Int: MovieCardView.ImageState] = [:]

    private let interactor: any CatalogInteractorProtocol
    weak var router: (any CatalogRouterProtocol)?

    nonisolated(unsafe) private var fetchTask: Task<Void, Never>?
    nonisolated(unsafe) private var posterTasks: [Int: Task<Void, Never>] = [:]

    init(interactor: any CatalogInteractorProtocol) {
        self.interactor = interactor
    }

    func handleAppear() {
        switch phase {
        case .loading, .loaded:
            return
        case .idle, .failed:
            startFetch()
        }
    }

    func handleRetry() {
        startFetch()
    }

    func handleMovieTap(movieId: Int) {
        router?.navigate(to: movieId)
    }

    private func startFetch() {
        fetchTask?.cancel()
        fetchTask = nil
        posterTasks.values.forEach { $0.cancel() }
        posterTasks = [:]

        phase = .loading
        imageStates = [:]

        fetchTask = Task { [weak self] in
            do throws(TMDBError) {
                let movies = try await self?.interactor.fetchTrending()
                guard !Task.isCancelled,
                      let movies else { return }
                if movies.isEmpty {
                    self?.phase = .failed(.networkFailure)
                    return
                }
                let rows = movies.map(CatalogMovieRow.init(movie:))
                self?.phase = .loaded(rows)
                self?.startPosterLoads(rows: rows)
            } catch {
                guard !Task.isCancelled,
                      let self else { return }
                self.phase = .failed(error)
            }
        }
    }

    private func startPosterLoads(rows: [CatalogMovieRow]) {
        for row in rows {
            guard let posterPath = row.posterPath else { continue }
            imageStates[row.id] = .placeholder
            posterTasks[row.id] = Task { [weak self] in
                guard let data = try? await self?.interactor.fetchPosterData(posterPath: posterPath) else { return }
                guard !Task.isCancelled,
                        let self else { return }
                guard let uiImage = UIImage(data: data) else { return }
                self.imageStates[row.id] = .image(Image(uiImage: uiImage))
            }
        }
    }

    deinit {
        fetchTask?.cancel()
        posterTasks.values.forEach { $0.cancel() }
    }
}
