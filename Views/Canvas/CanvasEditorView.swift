//
//  CanvasEditorView.swift
//  infinitenote
//

import SwiftUI
import UIKit
import PencilKit

struct CanvasEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InfiniteCanvasViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // Canvas - full screen
            CanvasRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            // Minimal overlay — PKToolPicker handles tools, colors, undo/redo
            HStack {
                // Back button
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer()

                // Settings menu (grid, draft mode, etc.)
                settingsMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .statusBarHidden()
    }

    // MARK: - Settings Menu

    private var settingsMenu: some View {
        Menu {
            // Draft mode
            Menu("Draft Mode") {
                ForEach(DraftMode.allCases, id: \.rawValue) { mode in
                    Button {
                        viewModel.draftMode = mode
                    } label: {
                        Label(mode.displayName, systemImage: mode == .off ? "square" : "square.dashed")
                        if viewModel.draftMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Grid
            Menu("Grid") {
                ForEach(GridType.allCases, id: \.rawValue) { gridType in
                    Button {
                        viewModel.gridSettings.type = gridType
                    } label: {
                        Label(gridType.displayName, systemImage: gridType.icon)
                        if viewModel.gridSettings.type == gridType {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Grid size
            if viewModel.gridSettings.type != .none {
                Menu("Grid Size") {
                    ForEach(GridSize.allCases, id: \.rawValue) { size in
                        Button {
                            viewModel.gridSettings.size = size
                        } label: {
                            Text(size.displayName)
                            if viewModel.gridSettings.size == size {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            // Reset view
            Button {
                NotificationCenter.default.post(name: .resetCanvas, object: nil)
            } label: {
                Label("Reset View", systemImage: "1.square")
            }

            // Clear
            Button(role: .destructive) {
                viewModel.clear()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let resetCanvas = Notification.Name("resetCanvas")
}

// MARK: - Representable

struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: InfiniteCanvasViewModel

    func makeUIView(context: Context) -> InfiniteCanvasUIView {
        let view = InfiniteCanvasUIView()
        view.viewModel = viewModel

        NotificationCenter.default.addObserver(
            forName: .resetCanvas,
            object: nil,
            queue: .main
        ) { _ in
            view.resetView()
        }

        return view
    }

    func updateUIView(_ uiView: InfiniteCanvasUIView, context: Context) {
        uiView.setNeedsDisplay()
    }
}

#Preview {
    CanvasEditorView()
}
