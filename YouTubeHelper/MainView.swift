//
//  MainView.swift
//  YouTubeHelper
//
//  Created by Nathan Kellert on 9/4/17.
//  Copyright © 2017 Nathan Kellert. All rights reserved.
//

import UIKit

class MainView: UIView {

    var playerView: YTPlayerView!
    var setup = false

    override func layoutSubviews() {

        if !setup{
            let width: CGFloat = frame.width - 16
            playerView = YTPlayerView(frame: CGRect(x: frame.width/2 - (width/2), y: frame.height/2 - (width * 0.5256), width: width, height: width * 0.5256))
            playerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            let didLoad = playerView.load(withVideoID: "M7lc1UVf-VE", andPlayerVars: getPlayerDictionary())
            if didLoad {
                addSubview(playerView)
                playerView.backgroundColor = .green
                playerView.delegate = self
            }
            setup = true
        }
        super.layoutSubviews()
    }

    func getPlayerDictionary() -> Dictionary<String, Any> {
        return [
            "playsinline" : 1,
            "showinfo" : 0,
            "controls" : 0,
            "modestbranding" : 1,
            "enablejsapi" : 1
        ]
    }
}

extension MainView: YTPlayerViewDelegate{
    func stateDidChange(forPlayerView playerView: YTPlayerView, toState state: YTPlayerState) {
        print(state)
    }
}
