//
//  MovieTrackerApp.swift
//  MovieTracker
//
//  Created by Tomasz Kubiak on 28/03/2026.
//

import PersistenceKit
import ReviewRepository
import SwiftData
import SwiftUI

@main
struct MovieTrackerApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerProvider.makeContainer(storeType: .persistent)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MovieTrackerRootView(modelContainer: modelContainer)
        }
        .modelContainer(modelContainer)
    }
}

private struct MovieTrackerRootView: View {
    private let reviewRepository: DefaultReviewRepository

    init(modelContainer: ModelContainer) {
        reviewRepository = DefaultReviewRepository.make(
            entityStore: ModelContainerProvider.makeReviewStore(container: modelContainer)
        )
    }

    var body: some View {
        ContentView()
            .environment(\.reviewRepository, reviewRepository)
    }
}
