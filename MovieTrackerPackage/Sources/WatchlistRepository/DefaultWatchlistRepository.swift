import DomainModels
import Foundation
import PersistenceKit

@MainActor
public final class DefaultWatchlistRepository: WatchlistRepository {
    private let store: WatchlistEntryStoring

    init(store: WatchlistEntryStoring) {
        self.store = store
    }

    public func add(movie: Movie) throws {
        let entry = watchlistEntry(from: movie, dateAdded: Date())
        let entity = entity(from: entry)
        do {
            try store.insert(entity)
        } catch PersistenceError.duplicateEntry {
            throw WatchlistRepositoryError.alreadyOnWatchlist
        } catch {
            throw WatchlistRepositoryError.insertFailed(error)
        }
    }

    public func remove(movieId: Int) throws {
        do {
            try store.delete(movieId: movieId)
        } catch PersistenceError.notFound {
            throw WatchlistRepositoryError.notFound
        } catch {
            throw WatchlistRepositoryError.deleteFailed(error)
        }
    }

    public func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry] {
        do {
            var entries = try store.fetch(predicate: nil).map(domainEntry(from:))
            guard let sortOrder else { return entries }
            switch sortOrder {
            case .dateAdded:
                entries.sort { $0.dateAdded > $1.dateAdded }
            case .title:
                entries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case .voteAverage:
                entries.sort { $0.voteAverage > $1.voteAverage }
            }
            return entries
        } catch {
            throw WatchlistRepositoryError.fetchFailed(error)
        }
    }

    public func contains(movieId: Int) throws -> Bool {
        let id = movieId
        do {
            let results = try store.fetch(predicate: #Predicate { $0.movieId == id })
            return !results.isEmpty
        } catch {
            throw WatchlistRepositoryError.fetchFailed(error)
        }
    }

    private func watchlistEntry(from movie: Movie, dateAdded: Date) -> WatchlistEntry {
        WatchlistEntry(
            movieId: movie.id,
            title: movie.title,
            releaseYear: Self.releaseYear(from: movie.releaseDate),
            voteAverage: movie.voteAverage,
            posterPath: movie.posterPath,
            dateAdded: dateAdded
        )
    }

    private func domainEntry(from entity: WatchlistEntryEntity) -> WatchlistEntry {
        WatchlistEntry(
            movieId: entity.movieId,
            title: entity.title,
            releaseYear: entity.releaseYear,
            voteAverage: entity.voteAverage,
            posterPath: entity.posterPath,
            dateAdded: entity.dateAdded
        )
    }

    private func entity(from entry: WatchlistEntry) -> WatchlistEntryEntity {
        WatchlistEntryEntity(
            movieId: entry.movieId,
            title: entry.title,
            releaseYear: entry.releaseYear,
            voteAverage: entry.voteAverage,
            posterPath: entry.posterPath,
            dateAdded: entry.dateAdded
        )
    }

    private static func releaseYear(from releaseDate: String) -> Int {
        let trimmed = releaseDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let prefix = String(trimmed.prefix(10))
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = iso.date(from: prefix) {
            return Calendar.current.component(.year, from: date)
        }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        if let date = df.date(from: prefix) {
            return Calendar.current.component(.year, from: date)
        }
        return 0
    }
}

public extension DefaultWatchlistRepository {
    @MainActor
    static func make(entityStore: any EntityStore<WatchlistEntryEntity>) -> DefaultWatchlistRepository {
        DefaultWatchlistRepository(store: SwiftDataWatchlistEntryStore(entityStore: entityStore))
    }
}
