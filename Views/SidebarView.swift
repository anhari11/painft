//
//  SidebarView.swift
//  infinitenote
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedProject: Project?
    @State private var projectsExpanded = true
    @State private var localFilesExpanded = true
    @State private var learningCenterExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar with Edit and display icon
            HStack {
                Button(action: {}) {
                    Text("Edit")
                        .font(.body)
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Logo
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .font(.title)
                    .foregroundColor(.primary)
                Text("Curve")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Workspace section
            VStack(alignment: .leading, spacing: 6) {
                Text("WORKSPACE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                HStack {
                    Text("Adam Anhari T...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text("Free")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Projects section
            SidebarSectionHeader(title: "Projects", isExpanded: $projectsExpanded)

            if projectsExpanded {
                // My Project row (selected)
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.body)
                        .foregroundColor(.orange)

                    Text("My Project")
                        .font(.body)
                        .foregroundColor(.orange)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                // Create New Project
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.body)
                        .foregroundColor(.orange)

                    Text("Create New Project")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }

            // Local Files section
            SidebarSectionHeader(title: "Local Files", isExpanded: $localFilesExpanded)
                .padding(.top, 8)

            if localFilesExpanded {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("On my iPad")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }

            // Learning Center section
            SidebarSectionHeader(title: "Learning Center", isExpanded: $learningCenterExpanded)
                .padding(.top, 8)

            if learningCenterExpanded {
                // Guides & Tutorials
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("Guides & Tutorials")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    // Red badge
                    Text("1")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                // News
                HStack(spacing: 10) {
                    Image(systemName: "newspaper")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("News")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }

            Spacer()

            // Try Pro button
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.body)
                        .foregroundColor(.orange)

                    Text("Try Pro for 7 days")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
    }
}

struct SidebarSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    SidebarView(selectedProject: .constant(nil))
}
