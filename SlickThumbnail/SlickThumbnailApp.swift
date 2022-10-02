//
//  SlickThumbnailApp.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/23/22.
//

import SwiftUI

@main
struct SlickThumbnailApp: App {
    let myPageViewModel = MyPageViewModel()
    var body: some Scene {
        WindowGroup {
            MyPageView(viewModel: myPageViewModel)
        }
    }
}
