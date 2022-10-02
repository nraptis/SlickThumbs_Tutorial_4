//
//  MyPageViewModel.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/23/22.
//

import SwiftUI

class MyPageViewModel: ObservableObject {
    
    private static let fetchCount = 32
    private static let probeAheadOrBehindRangeForPrefetch = 24
    private static let probeAheadOrBehindRangeForDownloads = 8
    
    static func mock() -> MyPageViewModel {
        return MyPageViewModel()
    }
    
    init() {
        layout.delegate = self
        downloader.delegate = self
        fetch(at: 0, withCount: Self.fetchCount, fromRefresh: false) { _ in }
    }
    
    private var model = MyPageModel()
    let layout = GridLayout()
    private let downloader = PriorityDataDownloader(numberOfSimultaneousDownloads: 2)
    
    private var numberOfActiveFetches = 0
    var isFetching: Bool { numberOfActiveFetches > 0 }
    private(set) var isRefreshing = false
    
    func numberOfThumbCells() -> Int {
        return model.totalExpectedCount
    }
    
    func thumbModel(at index: Int) -> ThumbModel? {
        return model.thumbModel(at: index)
    }
    
    func clear() {
        downloader.invalidateAndRemoveAllTasks()
        model = MyPageModel()
    }
    
    func fetch(at index: Int,
               withCount count: Int,
               fromRefresh refreshing: Bool,
               completion: @escaping ( Result<Void, ServiceError> ) -> Void) {
        
        if !refreshing {
            if isRefreshing {
                completion(.failure(.any))
                return
            }
        }
        
        numberOfActiveFetches += 1
        model.fetch(at: index, withCount: count) { result in
            switch result {
            case .success:
                self.numberOfActiveFetches -= 1
                completion(.success( () ))
                self.objectWillChange.send()
                self.fetchMoreThumbsIfNecessary()
            case .failure(let error):
                self.numberOfActiveFetches -= 1
                completion(.failure( error ))
                self.objectWillChange.send()
            }
        }
    }
    
    private func fetchMoreThumbsIfNecessary() {
        
        loadUpDownloaderWithTasks()
        
        if isFetching { return }
        
        let firstCellIndexOnScreen = layout.firstCellIndexOnScreen()
        let lastCellIndexOnScreen = layout.lastCellIndexOnScreen()
        
        // Case 1: Cells directly on screen
        var checkIndex = firstCellIndexOnScreen
        while checkIndex <= lastCellIndexOnScreen {
            if checkIndex >= 0 && checkIndex < model.totalExpectedCount {
                if thumbModel(at: checkIndex) == nil {
                    fetch(at: checkIndex, withCount: Self.fetchCount, fromRefresh: false) { _ in }
                    return
                }
            }
            checkIndex += 1
        }
        
        // Case 2: Cells shortly after screen's range of indices
        checkIndex = lastCellIndexOnScreen + 1
        while checkIndex <= (lastCellIndexOnScreen + Self.probeAheadOrBehindRangeForPrefetch) {
            if checkIndex >= 0 && checkIndex < model.totalExpectedCount {
                if thumbModel(at: checkIndex) == nil {
                    fetch(at: checkIndex, withCount: Self.fetchCount, fromRefresh: false) { _ in }
                    return
                }
            }
            checkIndex += 1
        }
        
        // Case 3: Cells shortly before screen's range of indices
        checkIndex = firstCellIndexOnScreen - Self.probeAheadOrBehindRangeForPrefetch
        while checkIndex < firstCellIndexOnScreen {
            if checkIndex >= 0 && checkIndex < model.totalExpectedCount {
                if thumbModel(at: checkIndex) == nil {
                    fetch(at: checkIndex, withCount: Self.fetchCount, fromRefresh: false) { _ in }
                    return
                }
            }
            checkIndex += 1
        }
    }
    
    private func loadUpDownloaderWithTasks() {
        
        let firstCellIndexOnScreen = layout.firstCellIndexOnScreen() - Self.probeAheadOrBehindRangeForDownloads
        let lastCellIndexOnScreen = layout.lastCellIndexOnScreen() + Self.probeAheadOrBehindRangeForDownloads
        
        for cellIndex in firstCellIndexOnScreen...lastCellIndexOnScreen {
            if let thumbModel = thumbModel(at: cellIndex), !didThumbDownloadSucceed(cellIndex) {
                downloader.addDownloadTask(thumbModel)
            }
        }
        
        // compute the priorities
        findDownloadPrioritiesForAllDownloadTasks()
        downloader.startTasksIfNecessary()
    }
    
    func forceRestartDownload(_ index: Int) {
        if let thumbModel = thumbModel(at: index) {
            downloader.forceRestartDownload(thumbModel)
        }
    }
    
    func didThumbDownloadSucceed(_ index: Int) -> Bool {
        return model.didThumbDownloadSucceed(index)
    }
    
    func didThumbDownloadFail(_ index: Int) -> Bool {
        return model.didThumbDownloadFail(index)
    }
    
    func isThumbDownloadingActively(_ index: Int) -> Bool {
        if let thumbModel = thumbModel(at: index) {
            return downloader.isActivelyDownloading(thumbModel)
        }
        return false
    }
    
    func refreshWrappingFetch() async {
        await withCheckedContinuation { continuation in
            self.fetch(at: 0, withCount: Self.fetchCount, fromRefresh: true) { _ in
                continuation.resume()
            }
        }
    }
    
    func refresh() async {
        
        isRefreshing = true
        
        //1.) Clear everything, wipe the screen
        await MainActor.run {
            self.clear()
            self.objectWillChange.send()
        }
        
        //2.) Wait for all the lingering fetches to complete...
        while isFetching {
            do {
                try await Task.sleep(nanoseconds: 1_000_000)
            } catch {
                isRefreshing = false
                return
            }
        }
        
        //3.) do the actual fetch
        await refreshWrappingFetch()
        
        //4.) wrap it up
        await MainActor.run {
            self.isRefreshing = false
            self.fetchMoreThumbsIfNecessary()
        }
    }
}

// This is for computing download priorities.
extension MyPageViewModel {
    
    // Distance from the left of the container / screen.
    // Distance from the top of the container / screen.
    private func priority(distX: Int, distY: Int) -> Int {
        
        let px = (-distX)
        let py = (8192 * 8192) - (8192 * distY)
        return (px + py)
    }
    
    func findDownloadPrioritiesForAllDownloadTasks() {
        
        let containerTopY = layout.getClippingContainerTop()
        let containerBottomY = layout.getClippingContainerBottom()
        let containerRangeY = containerTopY...containerBottomY
        
        for task in downloader.taskList {
            
            let cellIndex = task.thumbModelIndex
            let cellLeftX = layout.getClippingCellLeft(withCellIndex: cellIndex)
            let cellTopY = layout.getClippingCellTop(withCellIndex: cellIndex)
            let cellBottomY = layout.getClippingCellBottom(withCellIndex: cellIndex)
            let cellRangeY = cellTopY...cellBottomY
            
            let overlap = containerRangeY.overlaps(cellRangeY)
            
            if overlap {
                
                let distX = cellLeftX
                let distY = max(cellTopY - containerTopY, 0)
                let priority = priority(distX: distX, distY: distY)
                
                downloader.setPriority(task.thumbModel, priority)
            } else {
                // We aren't on the screen, low priority!
                downloader.setPriority(task.thumbModel, 0)
            }
        }
    }
}

extension MyPageViewModel: GridLayoutDelegate {
    
    func cellsDidEnterScreen(_ startIndex: Int, _ endIndex: Int) {
        fetchMoreThumbsIfNecessary()
    }
    
    func cellsDidLeaveScreen(_ startIndex: Int, _ endIndex: Int) {
        fetchMoreThumbsIfNecessary()
    }
}

extension MyPageViewModel: PriorityDataDownloaderDelegate {
    
    func dataDownloadDidStart(_ thumbModel: ThumbModel) {
        model.notifyDataDownloadStart(thumbModel)
        objectWillChange.send()
    }
    
    func dataDownloadDidSucceed(_ thumbModel: ThumbModel) {
        model.notifyDataDownloadSuccess(thumbModel)
        objectWillChange.send()
        loadUpDownloaderWithTasks()
    }
    
    func dataDownloadDidFail(_ thumbModel: ThumbModel) {
        model.notifyDataDownloadFailure(thumbModel)
        objectWillChange.send()
        loadUpDownloaderWithTasks()
    }
}
