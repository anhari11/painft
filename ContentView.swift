//
//  ContentView.swift
//  infinitenote
//
//  Created by Adam on 31/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedProject: Project? = Project.sampleProjects.first

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(selectedProject: $selectedProject)

            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1)

            // Main content
            MainContentView(projectName: selectedProject?.name ?? "My Project")
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
