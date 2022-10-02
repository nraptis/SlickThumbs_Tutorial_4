//
//  PriorityDataDownloaderTask.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/30/22.
//

import Foundation

class PriorityDataDownloaderTask {
    
    private weak var downloader: PriorityDataDownloader?
    let thumbModel: ThumbModel
    
    private(set) var active = false
    private(set) var priority: Int = 0
    
    init(_ downloader: PriorityDataDownloader, _ thumbModel: ThumbModel) {
        self.downloader = downloader
        self.thumbModel = thumbModel
    }
    
    var thumbModelIndex: Int { thumbModel.index }
    
    func setPriority(_ priority: Int) {
        self.priority = priority
    }
    
    func invalidate() {
        // cancel all network activity
        self.downloader = nil
    }
    
    func start() {
        active = true
        DispatchQueue.global(qos: .background).async {
            Thread.sleep(forTimeInterval: TimeInterval.random(in: 0.2...0.6))
            DispatchQueue.main.async {
                let failure = (Int.random(in: 0...12) == 0)
                if failure {
                    self.active = false
                    self.downloader?.handleDownloadTaskDidFail(self)
                } else {
                    self.active = false
                    self.downloader?.handleDownloadTaskDidSucceed(self)
                }
            }
        }
    }
}
