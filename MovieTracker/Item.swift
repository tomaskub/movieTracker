//
//  Item.swift
//  MovieTracker
//
//  Created by Tomasz Kubiak on 28/03/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
