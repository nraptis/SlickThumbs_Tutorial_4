//
//  ThumbModel.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/25/22.
//

import Foundation

// comes from mock web service
struct ThumbModel {
    
    static func mock() -> ThumbModel {
        return ThumbModel(index: 0, image: "🧫")
    }
    
    let index: Int
    let image: String
}

// stores local data about web service object
struct ThumbDownloadStatus {
    var downloadDidSucceed: Bool
    var downloadDidFail: Bool
}
