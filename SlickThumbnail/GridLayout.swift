//
//  GridLayout.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/23/22.
//

import SwiftUI

protocol GridLayoutDelegate: AnyObject {
    func cellsDidEnterScreen(_ startIndex: Int, _ endIndex: Int)
    func cellsDidLeaveScreen(_ startIndex: Int, _ endIndex: Int)
}

func isIpad() -> Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

class GridLayout {
    
    struct ThumbGridCellModel: ThumbGridConforming {
        let index: Int
        var id: Int { index }
    }
    
    weak var delegate: GridLayoutDelegate?
    
    // The content (grid) entire width and height
    private(set) var width: CGFloat = 255
    private(set) var height: CGFloat = 255
    
    // cell grid layout parameters
    let cellMaximumWidth = isIpad() ? 160 : 100
    let cellHeight = isIpad() ? 220 : 140
    
    let cellSpacingH = 9
    let cellPaddingLeft = 24
    let cellPaddingRight = 24
    
    let cellSpacingV = 9
    let cellPaddingTop = 24
    let cellPaddingBottom = 128
    
    private var _numberOfElements = 0
    private var _numberOfRows = 0
    private var _numberOfCols = 0 // needs to be computed BEFORE _numberOfRows
    
    private var _firstCellIndexOnScreen = 0
    private var _lastCellIndexOnScreen = 0
    
    private var _cellWidthArray = [Int]()
    private var _cellXArray = [Int]()
    private var _cellYArray = [Int]()
    
    private var _rowVisibleArray = [Bool]()
    private var _cellVisibleArray = [Bool]()
    
    private var _containerFrameInsetBySafeArea = CGRect.zero
    private var _containerFrameWithoutSafeArea = CGRect.zero
    private var _scrollContentFrame = CGRect.zero
    
    func registerContainer(_ containerGeometry: GeometryProxy, _ numberOfElements: Int) {
        
        let newContainerFrameInsetBySafeArea = containerGeometry.frame(in: .global)
        
        let left = containerGeometry.safeAreaInsets.leading
        let right = containerGeometry.safeAreaInsets.trailing
        let top = containerGeometry.safeAreaInsets.top
        let bottom = containerGeometry.safeAreaInsets.bottom

        let expandedX = newContainerFrameInsetBySafeArea.minX - left
        let expandedY = newContainerFrameInsetBySafeArea.minY - top
        let expandedHeight = newContainerFrameInsetBySafeArea.height + (top + bottom)
        let expandedWidth = newContainerFrameInsetBySafeArea.width + (left + right)
        
        let newContainerFrameWithoutSafeArea = CGRect(x: expandedX,
                                                      y: expandedY,
                                                      width: expandedWidth,
                                                      height: expandedHeight)
        
        // Did something change? If so, we want to re-layout our grid!
        if newContainerFrameInsetBySafeArea != _containerFrameInsetBySafeArea ||
            newContainerFrameWithoutSafeArea != _containerFrameWithoutSafeArea ||
            numberOfElements != _numberOfElements {
            _containerFrameInsetBySafeArea = newContainerFrameInsetBySafeArea
            _containerFrameWithoutSafeArea = newContainerFrameWithoutSafeArea
            _numberOfElements = numberOfElements
            layoutGrid()
        }
    }
    
    func registerScrollContent(_ scrollContentGeometry: GeometryProxy) {
        let newScrollContentFrame = scrollContentGeometry.frame(in: .global)
        _scrollContentFrame = newScrollContentFrame
        handleScrollContentDidChangePosition(_containerFrameWithoutSafeArea, _scrollContentFrame)
    }
    
    //use for clipping (show and hide cells, notify which cells are visible...)
    private static let onScreenPadding = 8
    private func handleScrollContentDidChangePosition(_ containerFrame: CGRect, _ scrollContentFrame: CGRect) {
        
        //container y range (adjusted by scroll offset)
        let containerTop = getClippingContainerTop() - Self.onScreenPadding
        let containerBottom = getClippingContainerBottom() + Self.onScreenPadding
        let containerRange = containerTop...containerBottom
        
        var shouldRefreshFirstAndLastCellIndexOnScreen = false
        for rowIndex in 0..<_numberOfRows {
            
            //row y range
            let rowTop = getClippingCellTop(withRowIndex: rowIndex)
            let rowBottom = getClippingCellBottom(withRowIndex: rowIndex)
            let rowRange = rowTop...rowBottom
            let overlap = containerRange.overlaps(rowRange)
            
            let firstCellIndex = firstCellIndexOf(row: rowIndex)
            let lastCellIndex = lastCellIndexOf(row: rowIndex)
            
            if overlap {
                //we are visible!!!
                if _rowVisibleArray[rowIndex] == false {
                    _rowVisibleArray[rowIndex] = true
                    for cellIndex in firstCellIndex...lastCellIndex {
                        _cellVisibleArray[cellIndex] = true
                    }
                    delegate?.cellsDidEnterScreen(firstCellIndex, lastCellIndex)
                    shouldRefreshFirstAndLastCellIndexOnScreen = true
                }
            } else {
                //we are off screen!!!
                if _rowVisibleArray[rowIndex] == true {
                    _rowVisibleArray[rowIndex] = false
                    for cellIndex in firstCellIndex...lastCellIndex {
                        _cellVisibleArray[cellIndex] = false
                    }
                    delegate?.cellsDidLeaveScreen(firstCellIndex, lastCellIndex)
                    shouldRefreshFirstAndLastCellIndexOnScreen = true
                }
            }
        }
        if shouldRefreshFirstAndLastCellIndexOnScreen {
            refreshFirstAndLastCellIndexOnScreen()
        }
    }
    
    private func hideAllVisibleCells() {
        var shouldRefreshFirstAndLastCellIndexOnScreen = false
        for rowIndex in 0..<_numberOfRows {
            if _rowVisibleArray[rowIndex] {
                _rowVisibleArray[rowIndex] = false
                let firstCellIndex = firstCellIndexOf(row: rowIndex)
                let lastCellIndex = lastCellIndexOf(row: rowIndex)
                for cellIndex in firstCellIndex...lastCellIndex {
                    _cellVisibleArray[cellIndex] = false
                }
                delegate?.cellsDidLeaveScreen(firstCellIndex, lastCellIndex)
                shouldRefreshFirstAndLastCellIndexOnScreen = true
            }
        }
        if shouldRefreshFirstAndLastCellIndexOnScreen {
            refreshFirstAndLastCellIndexOnScreen()
        }
    }
    
    private func layoutGrid() {
        
        hideAllVisibleCells()
        
        _numberOfCols = numberOfCols()
        _numberOfRows = numberOfRows()
        _cellWidthArray = cellWidthArray()
        _cellXArray = cellXArray()
        _cellYArray = cellYArray()
        buildVisibilityArrays()
        
        width = _containerFrameInsetBySafeArea.width
        height = CGFloat(_numberOfRows * cellHeight + (cellPaddingTop + cellPaddingBottom))
        //add the space between each cell vertically
        if _numberOfRows > 1 {
            height += CGFloat((_numberOfRows - 1) * cellSpacingV)
        }
    }
    
    func index(rowIndex: Int, colIndex: Int) -> Int {
        return (_numberOfCols * rowIndex) + colIndex
    }
    
    func col(index: Int) -> Int {
        if _numberOfCols > 0 {
            return index % _numberOfCols
        }
        return 0
    }
    
    func row(index: Int) -> Int {
        if _numberOfCols > 0 {
            return index / _numberOfCols
        }
        return 0
    }
    
    func firstCellIndexOf(row rowIndex: Int) -> Int {
        _numberOfCols * rowIndex
    }
    
    func lastCellIndexOf(row rowIndex: Int) -> Int {
        (_numberOfCols * rowIndex) + (_numberOfCols - 1)
    }
    
    func firstCellIndexOnScreen() -> Int {
        return _firstCellIndexOnScreen
    }
    
    func lastCellIndexOnScreen() -> Int {
        return _lastCellIndexOnScreen
    }
    
    func refreshFirstAndLastCellIndexOnScreen() {
        _firstCellIndexOnScreen = 0
        _lastCellIndexOnScreen = 0
        var found = false
        for rowIndex in 0..<_numberOfRows {
            if _rowVisibleArray[rowIndex] {
                if !found {
                    _firstCellIndexOnScreen = firstCellIndexOf(row: rowIndex)
                    _lastCellIndexOnScreen = lastCellIndexOf(row: rowIndex)
                    found = true
                } else {
                    _lastCellIndexOnScreen = lastCellIndexOf(row: rowIndex)
                }
            }
        }
    }
    
    private var _allVisibleCellModels = [ThumbGridCellModel]()
    func getAllVisibleCellModels() -> [ThumbGridCellModel] {
        _allVisibleCellModels.removeAll(keepingCapacity: true)
        for index in 0..<_numberOfElements {
            if index < _cellVisibleArray.count, _cellVisibleArray[index] {
                let newModel = ThumbGridCellModel(index: index)
                _allVisibleCellModels.append(newModel)
            }
        }
        return _allVisibleCellModels
    }
}

// clipping helpers
extension GridLayout {
    
    func getClippingContainerTop() -> Int {
        Int(_containerFrameWithoutSafeArea.minY - _scrollContentFrame.minY)
    }
    
    func getClippingContainerBottom() -> Int {
        Int(_containerFrameWithoutSafeArea.maxY - _scrollContentFrame.minY)
    }
    
    // cell top
    func getClippingCellTop(withCellIndex cellIndex: Int) -> Int {
        getClippingCellTop(withRowIndex: row(index: cellIndex))
    }
    
    func getClippingCellTop(withRowIndex rowIndex: Int) -> Int {
        if _cellYArray.count > 0 {
            var rowIndex = min(rowIndex, _cellYArray.count - 1)
            rowIndex = max(rowIndex, 0)
            return Int(_cellYArray[rowIndex])
        }
        return 0
    }
    
    // cell bottom
    func getClippingCellBottom(withCellIndex cellIndex: Int) -> Int {
        getClippingCellBottom(withRowIndex: row(index: cellIndex))
    }
    
    func getClippingCellBottom(withRowIndex rowIndex: Int) -> Int {
        getClippingCellTop(withRowIndex: rowIndex) + cellHeight
    }
    
    // cell left
    func getClippingCellLeft(withCellIndex cellIndex: Int) -> Int {
        getClippingCellLeft(withColIndex: col(index: cellIndex))
    }
    
    func getClippingCellLeft(withColIndex colIndex: Int) -> Int {
        if _cellXArray.count > 0 {
            var colIndex = min(colIndex, _cellXArray.count - 1)
            colIndex = max(colIndex, 0)
            return Int(_cellXArray[colIndex])
        }
        return 0
    }
}

// cell frame helpers
extension GridLayout {
    
    func getX(_ index: Int) -> CGFloat {
        var colIndex = col(index: index)
        if _cellXArray.count > 0 {
            colIndex = min(colIndex, _cellXArray.count - 1)
            colIndex = max(colIndex, 0)
            return CGFloat(_cellXArray[colIndex])
        }
        return 0
    }
    
    func getY(_ index: Int) -> CGFloat {
        var rowIndex = row(index: index)
        if _cellYArray.count > 0 {
            rowIndex = min(rowIndex, _cellYArray.count - 1)
            rowIndex = max(rowIndex, 0)
            return CGFloat(_cellYArray[rowIndex])
        }
        
        return 0
    }
    
    func getWidth(_ index: Int) -> CGFloat {
        var colIndex = col(index: index)
        if _cellWidthArray.count > 0 {
            colIndex = min(colIndex, _cellWidthArray.count - 1)
            colIndex = max(colIndex, 0)
            return CGFloat(_cellWidthArray[colIndex])
        }
        return 0
    }
    
    func getHeight(_ index: Int) -> CGFloat {
        return CGFloat(cellHeight)
    }
}

// grid layout helpers (internal)
extension GridLayout {
    
    func numberOfRows() -> Int {
        if _numberOfCols > 0 {
            var result = _numberOfElements / _numberOfCols
            if (_numberOfElements % _numberOfCols) != 0 { result += 1 }
            return result
        }
        return 0
    }
    
    func numberOfCols() -> Int {
        
        if _numberOfElements <= 0 { return 0 }
        
        var result = 1
        let availableWidth = _containerFrameInsetBySafeArea.width - CGFloat(cellPaddingLeft + cellPaddingRight)
        
        //try out horizontal counts until the cells would be
        //smaller than the maximum width
        
        var horizontalCount = 2
        while horizontalCount < 1024 {
            
            //the amount of space between the cells for this horizontal count
            let totalSpaceWidth = CGFloat((horizontalCount - 1) * cellSpacingH)
            
            let availableWidthForCells = availableWidth - totalSpaceWidth
            let expectedCellWidth = availableWidthForCells / CGFloat(horizontalCount)
            
            if expectedCellWidth < CGFloat(cellMaximumWidth) {
                break
            } else {
                result = horizontalCount
                horizontalCount += 1
            }
        }
        return result
    }
    
    func cellWidthArray() -> [Int] {
        var result = [Int]()
        
        var totalSpace = Int(_containerFrameInsetBySafeArea.width)
        totalSpace -= cellPaddingLeft
        totalSpace -= cellPaddingRight
        
        //subtract out the space between cells!
        if _numberOfCols > 1 {
            totalSpace -= (_numberOfCols - 1) * cellSpacingH
        }
        
        let baseWidth = totalSpace / _numberOfCols
        
        for _ in 0..<_numberOfCols {
            result.append(baseWidth)
            totalSpace -= baseWidth
        }
        
        //there might be a little space left over,
        //evenly distribute that remaining space...
        
        while totalSpace > 0 {
            for colIndex in 0..<_numberOfCols {
                result[colIndex] += 1
                totalSpace -= 1
                if totalSpace <= 0 { break }
            }
        }
        return result
    }
    
    func cellXArray() -> [Int] {
        var result = [Int]()
        var cellX = cellPaddingLeft
        for index in 0..<_numberOfCols {
            result.append(cellX)
            cellX += _cellWidthArray[index] + cellSpacingH
        }
        return result
    }
    
    func cellYArray() -> [Int] {
        var result = [Int]()
        var cellY = cellPaddingTop
        for _ in 0..<_numberOfRows {
            result.append(cellY)
            cellY += cellHeight + cellSpacingV
        }
        
        return result
    }
    
    func buildVisibilityArrays() {
        if _rowVisibleArray.count != _numberOfRows {
            _rowVisibleArray = [Bool](repeating: false, count: _numberOfRows)
        }
        
        let numberOfCells = _numberOfRows * _numberOfCols
        if _cellVisibleArray.count != numberOfCells {
            _cellVisibleArray = [Bool](repeating: false, count: numberOfCells)
        }
    }
}
