//
//  ThumbView.swift
//  SlickThumbnail
//
//  Created by Nick Raptis on 9/25/22.
//

import SwiftUI

struct ThumbView: View {
    
    let thumbModel: ThumbModel?
    let width: CGFloat
    let height: CGFloat
    let downloadDidSucceed: Bool
    let downloadDidFail: Bool
    let activelyDownloading: Bool
    let restartAction: (() -> Void)?
    
    private static let tileBackground = RoundedRectangle(cornerRadius: 12)
    
    private func progressView() -> some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    }
    
    private func thumbContent(_ thumbModel: ThumbModel) -> some View {
        ZStack {
            Text("\(thumbModel.image)")
                .font(.system(size: width * 0.5))
        }
        .frame(width: width, height: height)
        .background(Self.tileBackground.fill().foregroundColor(.orange).opacity(0.5))
    }
    
    private func placeholderContent() -> some View {
        ZStack {
            progressView()
        }
        .frame(width: width, height: height)
        .background(Self.tileBackground.fill().foregroundColor(.purple).opacity(0.5))
    }
    
    private func downloadingContent() -> some View {
        ZStack {
            progressView()
        }
        .frame(width: width, height: height)
        .background(Self.tileBackground.fill().foregroundColor(.gray).opacity(0.5))
    }
    
    private func activelyDownloadingContent() -> some View {
        ZStack {
            progressView()
        }
        .frame(width: width, height: height)
        .background(Self.tileBackground.fill().foregroundColor(.gray))
    }
    
    private func failedContent() -> some View {
        Button {
            restartAction?()
        } label: {
            ZStack {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 46).bold())
                    .foregroundColor(.white)
            }
            .frame(width: width, height: height)
            .background(Self.tileBackground.fill().foregroundColor(.red))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var body: some View {
        if let thumbModel = thumbModel {
            if downloadDidSucceed {
                thumbContent(thumbModel)
            } else if downloadDidFail {
                failedContent()
            } else {
                if activelyDownloading {
                    activelyDownloadingContent()
                } else {
                    downloadingContent()
                }
            }
        } else {
            placeholderContent()
        }
    }
}

struct ThumbView_Previews: PreviewProvider {
    static var previews: some View {
        ThumbView(thumbModel: ThumbModel.mock(),
                  width: 100,
                  height: 140,
                  downloadDidSucceed: false,
                  downloadDidFail: false,
                  activelyDownloading: false,
                  restartAction: nil)
    }
}
