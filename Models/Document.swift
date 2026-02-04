//
//  Document.swift
//  infinitenote
//

import SwiftUI

struct Document: Identifiable {
    let id = UUID()
    var title: String
    var date: Date?
    var thumbnailType: ThumbnailType

    enum ThumbnailType {
        case newDocument
        case newFolder
        case untitled
        case welcome
    }
}

extension Document {
    static let sampleDocuments: [Document] = [
        Document(title: "New Document", date: nil, thumbnailType: .newDocument),
        Document(title: "New Folder", date: nil, thumbnailType: .newFolder),
        Document(title: "Untitled", date: Date(), thumbnailType: .untitled),
        Document(title: "Welcome", date: Date().addingTimeInterval(-60), thumbnailType: .welcome)
    ]
}
