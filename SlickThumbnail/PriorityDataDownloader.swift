//
//  PriorityDataDownloader.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/30/22.
//

import Foundation

protocol PriorityDataDownloaderDelegate: AnyObject {
    func dataDownloadDidStart(_ thumbModel: ThumbModel)
    func dataDownloadDidSucceed(_ thumbModel: ThumbModel)
    func dataDownloadDidFail(_ thumbModel: ThumbModel)
}

class PriorityDataDownloader {
    
    weak var delegate: PriorityDataDownloaderDelegate?
    
    private let numberOfSimultaneousDownloads: Int
    init(numberOfSimultaneousDownloads: Int) {
        self.numberOfSimultaneousDownloads = numberOfSimultaneousDownloads
    }
    
    private(set) var taskList = [PriorityDataDownloaderTask]()
    private var failedThumbModelIndexSet = Set<Int>()
    private var _numberOfActiveDownloads = 0
    
    func addDownloadTask(_ thumbModel: ThumbModel) {
        guard !failedThumbModelIndexSet.contains(thumbModel.index) else { return }
        guard !doesTaskExist(thumbModel) else { return }
        
        let newTask = PriorityDataDownloaderTask(self, thumbModel)
        taskList.append(newTask)
        computeNumberOfActiveDownloads()
    }
    
    func removeDownloadTask(_ thumbModel: ThumbModel) {
        guard let index = taskIndex(thumbModel) else { return }
        taskList.remove(at: index)
        computeNumberOfActiveDownloads()
    }
    
    func forceRestartDownload(_ thumbModel: ThumbModel) {
        failedThumbModelIndexSet.remove(thumbModel.index)
        removeDownloadTask(thumbModel)
        addDownloadTask(thumbModel)
        if let index = taskIndex(thumbModel) {
            taskList[index].start()
            delegate?.dataDownloadDidStart(thumbModel)
        }
    }
    
    func invalidateAndRemoveAllTasks() {
        for task in taskList {
            task.invalidate()
        }
        taskList.removeAll()
        failedThumbModelIndexSet.removeAll()
        _numberOfActiveDownloads = 0
    }
    
    func doesTaskExist(_ thumbModel: ThumbModel) -> Bool { taskIndex(thumbModel) != nil }
    
    private func taskIndex(_ thumbModel: ThumbModel) -> Int? {
        for (index, task) in taskList.enumerated() {
            if task.thumbModelIndex == thumbModel.index { return index }
        }
        return nil
    }
    
    func setPriority(_ thumbModel: ThumbModel, _ priority: Int) {
        guard let index = taskIndex(thumbModel) else { return }
        taskList[index].setPriority(priority)
    }
    
    private func computeNumberOfActiveDownloads() {
        _numberOfActiveDownloads = 0
        for task in taskList {
            if task.active == true {
                _numberOfActiveDownloads += 1
            }
        }
    }
    
    func isActivelyDownloading(_ thumbModel: ThumbModel) -> Bool {
        if let index = taskIndex(thumbModel) {
            return taskList[index].active
        }
        return false
    }
    
    private func chooseTaskToStart() -> PriorityDataDownloaderTask? {
        
        // Choose the highest priority task (that is not active!)
        var highestPriority = Int.min
        var result: PriorityDataDownloaderTask?
        
        for task in taskList {
            if !task.active {
                if (result == nil) || (task.priority > highestPriority) {
                    highestPriority = task.priority
                    result = task
                }
            }
        }
        return result
    }
    
    func startTasksIfNecessary() {
        while _numberOfActiveDownloads < numberOfSimultaneousDownloads {
            if let task = chooseTaskToStart() {
                // start the task!
                task.start()
                computeNumberOfActiveDownloads()
                delegate?.dataDownloadDidStart(task.thumbModel)
            } else {
                // there are no tasks to start, must exit!
                return
            }
        }
    }
}

extension PriorityDataDownloader {
    func handleDownloadTaskDidSucceed(_ task: PriorityDataDownloaderTask) {
        removeDownloadTask(task.thumbModel)
        computeNumberOfActiveDownloads()
        delegate?.dataDownloadDidSucceed(task.thumbModel)
    }
    
    func handleDownloadTaskDidFail(_ task: PriorityDataDownloaderTask) {
        failedThumbModelIndexSet.insert(task.thumbModelIndex)
        removeDownloadTask(task.thumbModel)
        computeNumberOfActiveDownloads()
        delegate?.dataDownloadDidFail(task.thumbModel)
    }
}
