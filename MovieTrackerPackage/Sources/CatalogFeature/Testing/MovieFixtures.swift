#if DEBUG
import DomainModels

enum MovieFixtures {
    static let all: [Movie] = [
        Movie(
            id: 1,
            title: "Dune: Part Two",
            overview: "Paul Atreides unites with the Fremen.",
            releaseDate: "2024-03-01",
            genreIds: [878, 12],
            posterPath: "/dune2.jpg",
            voteAverage: 8.5
        ),
        Movie(
            id: 2,
            title: "Oppenheimer",
            overview: "The story of J. Robert Oppenheimer.",
            releaseDate: "2023-07-21",
            genreIds: [18, 36],
            posterPath: "/oppenheimer.jpg",
            voteAverage: 8.9
        ),
        Movie(
            id: 3,
            title: "Poor Things",
            overview: "A young woman brought back to life.",
            releaseDate: "2023-12-08",
            genreIds: [35, 10749],
            posterPath: nil,
            voteAverage: 7.8
        ),
        Movie(
            id: 4,
            title: "Past Lives",
            overview: "Two childhood sweethearts reunite.",
            releaseDate: "2023-06-02",
            genreIds: [18, 10749],
            posterPath: "/pastlives.jpg",
            voteAverage: 7.6
        ),
        Movie(
            id: 5,
            title: "The Zone of Interest",
            overview: "A Nazi commandant and his wife.",
            releaseDate: "2024-01-19",
            genreIds: [18, 36],
            posterPath: nil,
            voteAverage: 7.3
        ),
    ]
}
#endif
