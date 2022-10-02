//
//  ThumbGrid.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/24/22.
//

import SwiftUI

protocol ThumbGridConforming: Identifiable {
    var index: Int { get }
}

struct ThumbGrid<Item, ItemView>: View where Item: ThumbGridConforming, ItemView: View {
    
    let list: [Item]
    let layout: GridLayout
    let content: (Item) -> ItemView
    
    func thumb(item: Item) -> some View {
        let x = layout.getX(item.index)
        let y = layout.getY(item.index)
        return content(item).offset(x: x, y: y)
    }
    
    var body: some View {
        ForEach(list) { item in
            thumb(item: item)
        }
    }
}
