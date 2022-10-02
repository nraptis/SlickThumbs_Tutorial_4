//
//  MyPageModel.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/23/22.
//

import Foundation

enum ServiceError: Error {
    case any
}

class MyPageModel {
    
    private let allEmojis = "🚙🤗🦊🪗🪕🎻🐻‍❄️🚘🚕🏈⚾️🙊🙉🌲😄😁😆🚖🏎🚚🛻🎾🏐🥏🏓🥁😋🛩🚁🦓🦍🦧😌😛😎🥸🤩🦬🐃🦙🐐☹️😣😖😭🦣🦏🐪⛴🚢🚂🚝🚅😟😕🙁😤🎺🐎🐖🐏🐑🐶🐱🐭🍀🍁🍄🌾☁️🌦🌧⛈😅😂🤣🥲☺️🚛🚐🚓🥺😢🦎🦖🦕🥰😘😗😙🛸🚲☔️🐻🐼🐘🦛😍😚😠😡🤯💦🌊☂️🚤🛥🛳🚆🦇🐢🐍🐅🐆🛫🛬🏍🛶⛵️😳🥶😥🚗😓🐨🐯🦅🦉🐫🦒🙃😉🥳😏🐓🐁❄️💨💧🐰🦁🐮🥌🏂😔🏀⚽️🎼🎤🎹🪘🐥🐣🐂🐄🐵🙈🤭🤫🥀🌨🌫🦮🐈🦤😯😧✈️🚊🚔😝😜🤪🤨🐀🐒🦆🧐🤓🕊🦝🦨🦡😫😩🚉😴🤮🌺🌸😬🙄🥱🚀🚇🛺😞🤥😷🦌🐕🌴🌿☘️☀️🌤⛅️🌥😀😃🐩🦢🥅⛷🎳🚑🚒🚜🌷🌹🌼😇🙂🤧🦘🦩🦫🦦😊🤒🤠🐹🐷🐸🐲🌩🌪🦙🐐🦥🐿🦔💐🌻⛳️"
    
    private var thumbModelList = [ThumbModel?]()
    private var thumbDownloadStatusList = [ThumbDownloadStatus]()
    
    func thumbModel(at index: Int) -> ThumbModel? {
        if index >= 0 && index < thumbModelList.count {
            return thumbModelList[index]
        }
        return nil
    }
    
    func clear() {
        thumbModelList.removeAll()
        thumbDownloadStatusList.removeAll()
    }
    
    var totalExpectedCount: Int {
        return 118
    }
    
    private func simulateRangeFetchComplete(at index: Int, withCount count: Int) {
        let newCapacity = index + count
        
        if newCapacity <= 0 { return }
        guard count > 0 else { return }
        guard index < allEmojis.count else { return }
        if count > 8192 { return }
        
        let emojisArray = Array(allEmojis)
        
        while thumbModelList.count < newCapacity {
            thumbModelList.append(nil)
        }
        
        while thumbDownloadStatusList.count < newCapacity {
            let newStatus = ThumbDownloadStatus(downloadDidSucceed: false, downloadDidFail: false)
            thumbDownloadStatusList.append(newStatus)
        }
        
        var index = index
        while index < newCapacity {
            if index >= 0 && index < emojisArray.count, thumbModelList[index] == nil {
                let newModel = ThumbModel(index: index, image: String(emojisArray[index]))
                thumbModelList[index] = newModel
            }
            index += 1
        }
    }
    
    func fetch(at index: Int, withCount count: Int, completion: @escaping ( Result<Void, ServiceError> ) -> Void) {
        DispatchQueue.global(qos: .background).async {
            Thread.sleep(forTimeInterval: TimeInterval.random(in: 0.25...2.5))
            DispatchQueue.main.async {
                self.simulateRangeFetchComplete(at: index, withCount: count)
                completion(.success( () ))
            }
        }
    }
    
    private func inDownloadStatusRange(_ thumbModel: ThumbModel) -> Bool {
        if thumbModel.index >= 0 && thumbModel.index < thumbDownloadStatusList.count { return true }
        return false
    }
    
    private func setDownloadStatusSuccess(_ thumbModel: ThumbModel, _ value: Bool) {
        if inDownloadStatusRange(thumbModel) {
            thumbDownloadStatusList[thumbModel.index].downloadDidSucceed = value
        }
    }
    
    private func setDownloadStatusFailure(_ thumbModel: ThumbModel, _ value: Bool) {
        if inDownloadStatusRange(thumbModel) {
            thumbDownloadStatusList[thumbModel.index].downloadDidFail = value
        }
    }
    
    private func getDownloadStatusSuccess(_ thumbModel: ThumbModel) -> Bool {
        if inDownloadStatusRange(thumbModel) {
            return thumbDownloadStatusList[thumbModel.index].downloadDidSucceed
        }
        return false
    }
    
    private func getDownloadStatusFailure(_ thumbModel: ThumbModel) -> Bool {
        if inDownloadStatusRange(thumbModel) {
            return thumbDownloadStatusList[thumbModel.index].downloadDidFail
        }
        return false
    }
    
    func notifyDataDownloadSuccess(_ thumbModel: ThumbModel) {
        setDownloadStatusSuccess(thumbModel, true)
        setDownloadStatusFailure(thumbModel, false)
    }
    
    func notifyDataDownloadFailure(_ thumbModel: ThumbModel) {
        setDownloadStatusSuccess(thumbModel, false)
        setDownloadStatusFailure(thumbModel, true)
    }
    
    func notifyDataDownloadStart(_ thumbModel: ThumbModel) {
        setDownloadStatusSuccess(thumbModel, false)
        setDownloadStatusFailure(thumbModel, false)
    }
    
    func didThumbDownloadSucceed(_ index: Int) -> Bool {
        if let thumbModel = thumbModel(at: index) {
            return getDownloadStatusSuccess(thumbModel)
        }
        return false
    }
    
    func didThumbDownloadFail(_ index: Int) -> Bool {
        if let thumbModel = thumbModel(at: index) {
            return getDownloadStatusFailure(thumbModel)
        }
        return false
    }
}
