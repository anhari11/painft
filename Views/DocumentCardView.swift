//
//  DocumentCardView.swift
//  infinitenote
//

import SwiftUI

struct DocumentCardView: View {
    let document: Document

    private var formattedDate: String? {
        guard let date = document.date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/M/yy, HH:mm"
        return formatter.string(from: date)
    }

    private var isActionCard: Bool {
        document.thumbnailType == .newDocument || document.thumbnailType == .newFolder
    }

    var body: some View {
        VStack(alignment: isActionCard ? .center : .leading, spacing: 8) {
            // Thumbnail
            thumbnailView
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Title
            Text(document.title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // Date
            if let date = formattedDate {
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        switch document.thumbnailType {
        case .newDocument:
            NewDocumentThumbnail()
        case .newFolder:
            NewFolderThumbnail()
        case .untitled:
            UntitledThumbnail()
        case .welcome:
            WelcomeThumbnail()
        }
    }
}

struct NewDocumentThumbnail: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))

            Image(systemName: "plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color(.systemGray2))
        }
    }
}

struct NewFolderThumbnail: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))

            VStack(spacing: 4) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color(.systemGray2))
            }
        }
    }
}

struct UntitledThumbnail: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))

            // Blue illustration - person figure
            GeometryReader { geo in
                ZStack {
                    // Abstract blue figure
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height

                        // Body curve
                        path.move(to: CGPoint(x: w * 0.3, y: h * 0.7))
                        path.addCurve(
                            to: CGPoint(x: w * 0.5, y: h * 0.3),
                            control1: CGPoint(x: w * 0.35, y: h * 0.5),
                            control2: CGPoint(x: w * 0.4, y: h * 0.35)
                        )
                        path.addCurve(
                            to: CGPoint(x: w * 0.7, y: h * 0.6),
                            control1: CGPoint(x: w * 0.6, y: h * 0.25),
                            control2: CGPoint(x: w * 0.65, y: h * 0.4)
                        )
                    }
                    .stroke(Color.blue.opacity(0.7), lineWidth: 20)
                    .blur(radius: 1)

                    // Head circle
                    Circle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.25)

                    // Arms
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height

                        path.move(to: CGPoint(x: w * 0.35, y: h * 0.45))
                        path.addCurve(
                            to: CGPoint(x: w * 0.2, y: h * 0.5),
                            control1: CGPoint(x: w * 0.3, y: h * 0.42),
                            control2: CGPoint(x: w * 0.25, y: h * 0.48)
                        )

                        path.move(to: CGPoint(x: w * 0.55, y: h * 0.35))
                        path.addCurve(
                            to: CGPoint(x: w * 0.8, y: h * 0.3),
                            control1: CGPoint(x: w * 0.65, y: h * 0.32),
                            control2: CGPoint(x: w * 0.75, y: h * 0.28)
                        )
                    }
                    .stroke(Color.blue.opacity(0.7), lineWidth: 12)
                }
            }
            .padding(20)
        }
    }
}

struct WelcomeThumbnail: View {
    var body: some View {
        ZStack {
            // Gradient background - space scene
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.3, blue: 0.5),
                    Color(red: 0.2, green: 0.25, blue: 0.4),
                    Color(red: 0.15, green: 0.2, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Stars (fixed positions)
            GeometryReader { geo in
                let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
                    (0.1, 0.15, 2), (0.25, 0.08, 3), (0.4, 0.2, 2),
                    (0.55, 0.05, 2.5), (0.7, 0.18, 2), (0.85, 0.1, 3),
                    (0.15, 0.35, 2), (0.9, 0.3, 2.5)
                ]
                ForEach(0..<starPositions.count, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: starPositions[i].size, height: starPositions[i].size)
                        .position(
                            x: geo.size.width * starPositions[i].x,
                            y: geo.size.height * starPositions[i].y
                        )
                }
            }

            // Planet
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.8), Color.red.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .offset(x: 80, y: -30)

            // Ground/mountains
            VStack {
                Spacer()

                ZStack(alignment: .bottom) {
                    // Mountains background
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 60))
                        path.addLine(to: CGPoint(x: 60, y: 20))
                        path.addLine(to: CGPoint(x: 120, y: 50))
                        path.addLine(to: CGPoint(x: 180, y: 15))
                        path.addLine(to: CGPoint(x: 250, y: 45))
                        path.addLine(to: CGPoint(x: 300, y: 60))
                        path.addLine(to: CGPoint(x: 300, y: 80))
                        path.addLine(to: CGPoint(x: 0, y: 80))
                        path.closeSubpath()
                    }
                    .fill(Color(red: 0.3, green: 0.25, blue: 0.35))

                    // Ground
                    Rectangle()
                        .fill(Color(red: 0.35, green: 0.3, blue: 0.4))
                        .frame(height: 30)
                }
                .frame(height: 80)
            }

            // "THE FINAL QUEST" text
            VStack {
                Spacer()
                Text("THE FINAL QUEST")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 12)
            }

            // UI elements overlay (tooltips)
            VStack {
                HStack {
                    Spacer()

                    // Tooltip 1
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Move this rock using")
                            .font(.system(size: 5))
                        Text("the Selection Tool")
                            .font(.system(size: 5, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(4)
                    .padding(.top, 25)
                    .padding(.trailing, 15)
                }

                Spacer()

                HStack {
                    // Tooltip 2
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Unlock the box with")
                            .font(.system(size: 5))
                        Text("the Text Tool")
                            .font(.system(size: 5, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(4)
                    .padding(.bottom, 35)
                    .padding(.leading, 15)

                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack(spacing: 20) {
        DocumentCardView(document: Document.sampleDocuments[0])
            .frame(width: 180)
        DocumentCardView(document: Document.sampleDocuments[1])
            .frame(width: 180)
        DocumentCardView(document: Document.sampleDocuments[2])
            .frame(width: 180)
    }
    .padding()
}
