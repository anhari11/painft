//
//  Project.swift
//  infinitenote
//

import SwiftUI

struct Project: Identifiable {
    let id = UUID()
    var name: String
    var isSelected: Bool = false
}

extension Project {
    static let sampleProjects: [Project] = [
        Project(name: "My Project", isSelected: true)
    ]
}
