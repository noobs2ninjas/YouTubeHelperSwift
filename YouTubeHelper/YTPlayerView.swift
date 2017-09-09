//
//  YouTubeView.swift
//  YouTubeHelper
//
//  Created by Nathan Kellert on 9/4/17.
//  Copyright © 2017 Nathan Kellert. All rights reserved.
//

import UIKit
import WebKit

enum YTPlayerState {
    case unstarted
    case ended
    case playing
    case paused
    case buffering
    case queued
    case unknown

    init(string: String){
        let dictionary: Dictionary<String, YTPlayerState>  = [
            "-1" : .unstarted,
            "0" : .ended,
            "1" : .playing,
            "2" : .paused,
            "3" : .queued,
            "5" : .buffering,
            "unknown" : .unknown
        ]
        self = dictionary[string] ?? .unknown
    }
}

fileprivate enum YTPlayerCallBack{
    case onReady
    case onStateChange
    case onPlaybackQualityChange
    case onError
    case onPlayTime
    case unknown

    init(string: String) {
        let dictionary: Dictionary<String, YTPlayerCallBack> = [
            "onReady" : .onReady,
            "onStateChange" : .onStateChange,
            "onPlaybackQualityChange" : .onPlaybackQualityChange,
            "onError" : .onError,
            "onPlayTime" : .onPlayTime
        ]

        self = dictionary[string] ?? .unknown
    }
}

enum YTPlayerError{
    case invalidParameter
    case htmlError
    case videoNotFound
    case videoNotEmbeddable
    case cannotFindVideo
    case unknown

    init(string: String) {
        let dictionary: Dictionary<String, YTPlayerError> = [
            "2" : .invalidParameter,
            "5" : .htmlError,
            "100" : .videoNotFound,
            "101" : .videoNotEmbeddable,
            "105" : .cannotFindVideo,
            "150" : .videoNotEmbeddable
        ]

        self = dictionary[string] ?? .unknown
    }

}


protocol YTPlayerViewDelegate: class {
    func playerViewDidBecomeReady(_ playerView: YTPlayerView)
    func stateDidChange(forPlayerView playerView: YTPlayerView, toState state: YTPlayerState)
    func preferedInitialLoadingView(forPlayerView playerView: YTPlayerView) -> UIView?
    func didRecieveError(error: YTPlayerError, forPlayerView: YTPlayerView)
    func playerView(_ playerView: YTPlayerView, didPlaytime time: Float)
}

extension YTPlayerViewDelegate {
    func playerViewDidBecomeReady(_ playerView: YTPlayerView) {}
    func stateDidChange(forPlayerView playerView: YTPlayerView, toState state: YTPlayerState) {}
    func preferedInitialLoadingView(forPlayerView playerView: YTPlayerView) -> UIView? { return nil }
    func didRecieveError(error: YTPlayerError, forPlayerView: YTPlayerView) {}
    func playerView(_ playerView: YTPlayerView, didPlaytime time: Float){}
}

class YTPlayerView: UIView {

    public typealias YouTubeCompletion = (Any?, Error?) -> Void

    public var delegate: YTPlayerViewDelegate?
    public var webView: WKWebView!
    public var state: YTPlayerState = .unknown

    private var initialLoadingView: UIView?
    private var originUrl: URL!


    func playVideo(){
        getStringByEvaluating(javaScript: "player.playVideo();") { (object, error) in
            if error != nil { debugPrint(error!) }
        }
    }

    func pauseVideo(){
        if let url = URL(string: "ytplayer://onStateChange?data=5"){
            notifyDelegate(forCallbackUrl: url)
            getStringByEvaluating(javaScript: "player.pauseVideo();") { (object, error) in
                if error != nil { debugPrint(error!) }
            }
        }
    }

    func stopVideo(){
        getStringByEvaluating(javaScript: "player.stopVideo();") { (object, error) in
            if error != nil { debugPrint(error!) }
        }
    }

    func load(withVideoID videoId: String, andPlayerVars playerVars: Dictionary<String, Any>) -> Bool{
        let playerParams: Dictionary<String, Any> = ["videoId" : videoId, "playerVars" : playerVars]
        return load(withPlayerParams: playerParams)
    }

    func load(withPlayerParams addionalPlayerParams: Dictionary<String, Any>) -> Bool {

        var playerParams:Dictionary<String, Any> = addionalPlayerParams

        if playerParams["height"] == nil {
            playerParams["height"] = "100%"
        }

        if playerParams["width"] == nil {
            playerParams["width"] = "100%"
        }

        playerParams["events"] = [
            "onReady" : "onReady",
            "onStateChange" : "onStateChange",
            "onPlayerQualityChange" : "onPlayerQualityChange",
            "onError" : "onPlayerError"
        ]

        if let variables = playerParams["playerVars"] as? Dictionary<String, Any> {
            if let origin = variables["origin"] as? String, let url = URL(string: origin) {
                originUrl = url
            } else {
                originUrl = URL(string: "about:blank")
            }
        } else { playerParams["playerVars"] = [:] }


        if let bundleString = Bundle.main.path(forResource: "Assets", ofType: "bundle"), let bundle = Bundle(path: bundleString), let path = bundle.path(forResource: "YTPlayerView-iframe-player", ofType: "html", inDirectory: "Assets"){

            if webView != nil { webView.removeFromSuperview() }
            webView = createNewWebView()
            addSubview(webView)
            webView.setNeedsLayout()

            do {

                let embeddedHTMLTemplate = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                let jsonData = try JSONSerialization.data(withJSONObject: playerParams, options: .prettyPrinted)
                
                if let playerVarsJsonString = String(data: jsonData, encoding: String.Encoding.utf8){
                    let embedHTML = String(format: embeddedHTMLTemplate, playerVarsJsonString)
                    print(embedHTML)
                    webView.loadHTMLString(embedHTML, baseURL: originUrl)
                }

                if let initialLoadingView = delegate?.preferedInitialLoadingView(forPlayerView: self) {
                    initialLoadingView.frame = bounds
                    initialLoadingView.autoresizingMask =  [.flexibleHeight, .flexibleWidth]
                    addSubview(initialLoadingView)
                    self.initialLoadingView = initialLoadingView
                }


            } catch let error {
                debugPrint("Recieved error getting data: ", error)
                return false
            }
        } else {
            debugPrint("Didnt Find HTML File")
            return false
        }

        return true
    }

    func getStringByEvaluating(javaScript script: String, completion:@escaping YouTubeCompletion) {
        webView.evaluateJavaScript(script) { (object, error) in
            completion(object, error)
        }
    }

   fileprivate func createNewWebView()->WKWebView {

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.mediaPlaybackRequiresUserAction = false
        }
        configuration.applicationNameForUserAgent = "Safari"

        //setting user defaults to that user agent
        UserDefaults.standard.register(defaults: ["UserAgent" : "Mozilla/5.0 (iPhone) AppleWebKit/603.1.30 (HTML) Mobile/14E8301"])

        let rect = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        let webView = WKWebView(frame: rect, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = self
        webView.bounds = rect

        //printing UIWebView UserAgent
        let oldWebView = UIWebView.init(frame: rect)
        let userAgent = oldWebView.stringByEvaluatingJavaScript(from: "navigator.userAgent")
        self.addSubview(oldWebView)
        print(userAgent)

        return webView
    }

  fileprivate func notifyDelegate(forCallbackUrl url: URL){

        if let action = url.host{
            let playerCallback = YTPlayerCallBack(string: action)
            switch playerCallback {
            case .onReady:
                initialLoadingView?.removeFromSuperview()
                delegate?.playerViewDidBecomeReady(self)
                break
            case .onStateChange:
                if let data = url.query?.components(separatedBy: "=")[1]{
                    state = YTPlayerState(string: data)
                    delegate?.stateDidChange(forPlayerView: self, toState: state)
                }
                break
            case .onPlaybackQualityChange:
                print("implement quality change")
                break
            case .onError:
                if let data = url.query?.components(separatedBy: "=")[1]{
                    let error = YTPlayerError(string: data)
                    delegate?.didRecieveError(error: error, forPlayerView: self)
                }
                break
            case .onPlayTime:
                if let data = url.query?.components(separatedBy: "=")[1]{
                    let time = data.floatValue
                    delegate?.playerView(self, didPlaytime: time)
                }
                break
            default:
                initialLoadingView?.removeFromSuperview()
                break
            }

        }
    }

    func removeWebView(){
        self.webView.removeFromSuperview()
        webView = nil
    }

}

extension YTPlayerView : WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print(navigationAction.request.url)
        if let url = navigationAction.request.url, let scheme = url.scheme, scheme == "ytplayer"{
            self.notifyDelegate(forCallbackUrl: url)
            decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

}

fileprivate extension String {
    var floatValue: Float {
        return (self as NSString).floatValue
    }
}
