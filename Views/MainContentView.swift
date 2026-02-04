//
//  MainContentView.swift
//  infinitenote
//

import SwiftUI

struct MainContentView: View {
    let projectName: String
    @State private var documents: [Document] = Document.sampleDocuments
    @State private var showCanvasEditor = false

    private var actionCards: [Document] {
        documents.filter { $0.thumbnailType == .newDocument || $0.thumbnailType == .newFolder }
    }

    private var regularDocuments: [Document] {
        documents.filter { $0.thumbnailType != .newDocument && $0.thumbnailType != .newFolder }
    }

    private var itemCount: Int {
        regularDocuments.count
    }

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 24)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            // Banners
            bannersView

            // Document grid
            ScrollView {
                VStack(spacing: 0) {
                    // Action cards (New Document, New Folder) - left aligned
                    HStack(spacing: 24) {
                        ForEach(actionCards) { document in
                            DocumentCardView(document: document)
                                .frame(width: 180)
                                .onTapGesture {
                                    if document.thumbnailType == .newDocument {
                                        showCanvasEditor = true
                                    }
                                }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                    // Thin separator line
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .padding(.horizontal, 32)

                    // Regular documents grid
                    if !regularDocuments.isEmpty {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(regularDocuments) { document in
                                DocumentCardView(document: document)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                    }

                    // Item count
                    Text("\(itemCount) items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showCanvasEditor) {
            CanvasEditorView()
        }
    }

    private var headerView: some View {
        HStack {
            Text(projectName)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Toolbar buttons
            HStack(spacing: 20) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.primary)
                }

                Button(action: {}) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }

                Button(action: {}) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }

                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private var bannersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Orange usage banner
            HStack(spacing: 4) {
                Text("You've used 2/8 of your free Curve files.")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Button(action: {}) {
                    Text("Try Pro for free")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }

            // Gray info text
            Group {
                Text("In the ")
                    .foregroundColor(.secondary)
                +
                Text("Free plan")
                    .underline()
                    .foregroundColor(.secondary)
                +
                Text(", you can only edit the 8 most recently edited files. ")
                    .foregroundColor(.secondary)
                +
                Text("Upgrade")
                    .underline()
                    .foregroundColor(.secondary)
                +
                Text(" your plan or delete files to unlock editing for additional files.")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
}

#Preview {
    MainContentView(projectName: "My Project")
}
