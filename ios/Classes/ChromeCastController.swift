//
//  ChromeCastController.swift
//  flutter_cast_video
//
//  Created by Alessio Valentini on 07/08/2020.
//

import Flutter
#if canImport(GoogleCast)
import GoogleCast
#endif

class ChromeCastController: NSObject, FlutterPlatformView {
    
    // MARK: - Internal properties
    
    private let channel: FlutterMethodChannel
#if canImport(GoogleCast)
    private let chromeCastButton: GCKUICastButton
    private let sessionManager = GCKCastContext.sharedInstance().sessionManager
#endif
    // MARK: - Init
    
    init(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        registrar: FlutterPluginRegistrar
    ) {
        self.channel = FlutterMethodChannel(name: "flutter_cast_video/chromeCast_\(viewId)", binaryMessenger: registrar.messenger())
#if canImport(GoogleCast)
        self.chromeCastButton = GCKUICastButton(frame: frame)
#endif
        super.init()
        self.configure(arguments: args)
    }
    
    func view() -> UIView {
#if canImport(GoogleCast)
        return chromeCastButton
#else
        return UIView()
#endif
    }
    
    private func configure(arguments args: Any?) {
        setTint(arguments: args)
        setMethodCallHandler()
    }
    
    // MARK: - Styling
    
    private func setTint(arguments args: Any?) {
        guard
            let args = args as? [String: Any],
            let red = args["red"] as? CGFloat,
            let green = args["green"] as? CGFloat,
            let blue = args["blue"] as? CGFloat,
            let alpha = args["alpha"] as? Int else {
            print("Invalid color")
            return
        }
#if canImport(GoogleCast)
        chromeCastButton.tintColor = UIColor(
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            alpha: CGFloat(alpha) / 255
        )
#endif
    }
    
    // MARK: - Flutter methods handling
    
    private func setMethodCallHandler() {
        channel.setMethodCallHandler { call, result in
            self.onMethodCall(call: call, result: result)
        }
    }
    
    private func setVolume(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let volume = args["volume"] as? Float,
            let client = sessionManager.currentCastSession?.remoteMediaClient else {
            return
        }
        client.setStreamVolume(volume);
#endif
    }
    
    private func getPlaybackRate() -> Float? {
#if canImport(GoogleCast)
        return sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.playbackRate
#else
        return 1.0
#endif
    }
    
    private func setPlaybackRate(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let rate = args["rate"] as? Float,
            let client = sessionManager.currentCastSession?.remoteMediaClient else {
            return
        }
        client.setPlaybackRate(rate).delegate = self
#endif
    }
    
    private func getAudioTrack() -> String? {
#if canImport(GoogleCast)
        guard
            let client = sessionManager.currentCastSession?.remoteMediaClient,
            let tracks = client.mediaStatus?.mediaInformation?.mediaTracks?.filter({(track) -> Bool in track.type == GCKMediaTrackType.audio }),
            let ids = sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIDs
        else {
            return nil
        }
        
        return tracks.first { track in
            ids.contains(track.identifier as NSNumber)
        }?.languageCode
#else
        return nil
#endif
    }
    
    private func setAudioTrack(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let lang = args["lang"] as? String,
            let client = sessionManager.currentCastSession?.remoteMediaClient,
            let tracks = client.mediaStatus?.mediaInformation?.mediaTracks?.filter({(track) -> Bool in track.type == GCKMediaTrackType.audio }),
            let selectedTrackId = tracks.first(where: {track in track.languageCode == lang})?.identifier as NSNumber?
        else {
            return
        }
        
        let trackIds = tracks.map({ track in
            track.identifier
        })
        var ids = client.mediaStatus?.activeTrackIDs?.filter{id in !trackIds.contains(Int(truncating: id))} ?? []
        ids.append(selectedTrackId)
        client.setActiveTrackIDs(ids).delegate = self
#endif
    }
    
    private func getSubtitleTrack() -> String? {
#if canImport(GoogleCast)
        guard
            let client = sessionManager.currentCastSession?.remoteMediaClient,
            let tracks = client.mediaStatus?.mediaInformation?.mediaTracks?.filter({(track) -> Bool in track.type == GCKMediaTrackType.text }),
            let ids = sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIDs
        else {
            return ""
        }
        
        return tracks.first { track in
            ids.contains(track.identifier as NSNumber)
        }?.languageCode
#else
        return nil
#endif
    }
    
    private func setSubtitleTrack(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let lang = args["lang"] as? String,
            let client = sessionManager.currentCastSession?.remoteMediaClient,
            let tracks = client.mediaStatus?.mediaInformation?.mediaTracks?.filter({(track) -> Bool in track.type == GCKMediaTrackType.text })
        else {
            return
        }

        if lang.isEmpty {
            client.setActiveTrackIDs([]).delegate = self
        } else {
            guard let selectedTrackId = tracks.first(where: {track in track.languageCode == lang})?.identifier as NSNumber? else {
                return
            }
            
            let trackIds = tracks.map({ track in
                track.identifier
            })
            var ids = client.mediaStatus?.activeTrackIDs?.filter{id in !trackIds.contains(Int(truncating: id))} ?? []
            ids.append(selectedTrackId)
            client.setActiveTrackIDs(ids).delegate = self

        }
#endif
    }
    
    
    private func onMethodCall(call: FlutterMethodCall, result: FlutterResult) {
#if canImport(GoogleCast)
        switch call.method {
        case "chromeCast#wait":
            result(nil)
            break
        case "chromeCast#loadMedia":
            loadMedia(args: call.arguments)
            result(nil)
            break
        case "chromeCast#play":
            play()
            result(nil)
            break
        case "chromeCast#pause":
            pause()
            result(nil)
            break
        case "chromeCast#seek":
            seek(args: call.arguments)
            result(nil)
            break
        case "chromeCast#setVolume":
            setVolume(args: call.arguments)
            result(nil)
            break
        case "chromeCast#stop":
            stop()
            result(nil)
            break
        case "chromeCast#isConnected":
            result(isConnected())
            break
        case "chromeCast#duration":
            result(duration())
            break
        case "chromeCast#isPlaying":
            result(isPlaying())
            break
        case "chromeCast#getMediaInfo":
            result(getMediaInfo())
            break
        case "chromeCast#addSessionListener":
            addSessionListener()
            result(nil)
        case "chromeCast#removeSessionListener":
            removeSessionListener()
            result(nil)
        case "chromeCast#position":
            result(position())
        case "chromeCast#getPlaybackRate":
            result(getPlaybackRate())
        case "chromeCast#setPlaybackRate":
            setPlaybackRate(args: call.arguments)
            result(nil)
        case "chromeCast#getAudioTrack":
            result(getAudioTrack())
        case "chromeCast#setAudioTrack":
            setAudioTrack(args: call.arguments)
            result(nil)
        case "chromeCast#getSubtitleTrack":
            result(getSubtitleTrack())
        case "chromeCast#setSubtitleTrack":
            setSubtitleTrack(args: call.arguments)
            result(nil)
        case "chromeCast#performClick":
            chromeCastButton.sendActions(for: .touchUpInside)
            result(nil)
        default:
            result(nil)
            break
        }
#else
        result(nil)
#endif
    }
    
    private func loadMedia(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let url = args["url"] as? String,
            let mediaUrl = URL(string: url) else {
            print("Invalid URL")
            return
        }
        
        let _title = args["title"] as? String
        let _subtitle = args["subtitle"] as? String
        let _image = args["image"] as? String
        let live = args["live"] as? Bool
        let contentType = args["contentType"] as? String ?? "video/mp4"
        let hlsVideoSegmentFormat = args["hlsVideoSegmentFormat"] as? Int ?? 0
        let customData = args["customData"] as? [AnyHashable: AnyHashable]
        
        let movieMetadata = GCKMediaMetadata()
        
        if let title = _title {
            movieMetadata.setString(title, forKey: kGCKMetadataKeyTitle)
        }
        if let subtitle = _subtitle {
            movieMetadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
        }
        if let image = _image {
            if let imageUrl = URL(string: image){
                movieMetadata.addImage(GCKImage(url: imageUrl, width: 480, height: 360))
            }
        }
        
        let mediaInfoBuilder = GCKMediaInformationBuilder.init(contentURL: mediaUrl)
        
        mediaInfoBuilder.metadata = movieMetadata

        mediaInfoBuilder.streamType = .buffered
        // 
        mediaInfoBuilder.contentType = contentType
        //
        mediaInfoBuilder.hlsVideoSegmentFormat = GCKHLSVideoSegmentFormat(rawValue: hlsVideoSegmentFormat) ?? .FMP4
        // 
        mediaInfoBuilder.customData = customData

        // 
        if let islive = live {
            if islive {
                mediaInfoBuilder.streamType = .live
            }
        }
        
        let mediaInformation = mediaInfoBuilder.build()
        
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.loadMedia(mediaInformation) {
            request.delegate = self
        }
#endif
    }
    
    private func play() {
#if canImport(GoogleCast)
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.play() {
            request.delegate = self
        }
#endif
    }
    
    private func pause() {
#if canImport(GoogleCast)
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.pause() {
            request.delegate = self
        }
#endif
    }
    
    private func seek(args: Any?) {
#if canImport(GoogleCast)
        guard
            let args = args as? [String: Any],
            let relative = args["relative"] as? Bool,
            let interval = args["interval"] as? Double else {
            return
        }
        let seekOptions = GCKMediaSeekOptions()
        seekOptions.relative = relative
        seekOptions.interval = interval
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.seek(with: seekOptions) {
            request.delegate = self
        }
#endif
    }
    
    private func stop() {
#if canImport(GoogleCast)
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.stop() {
            request.delegate = self
        }
#endif
    }
    
    private func getMediaInfo() -> [String: AnyHashable?]? {
#if canImport(GoogleCast)
        return  mediaInfoToMap(_mediaInfo: sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.mediaInformation)
#else
        return nil
#endif
    }
    
#if canImport(GoogleCast)
    private func mediaInfoToMap(_mediaInfo: GCKMediaInformation?) -> [String: AnyHashable?]? {
        var info = [String: AnyHashable?]()
        if let mediaInfo = _mediaInfo {
            info["id"] = mediaInfo.contentID
            if let u = mediaInfo.contentURL {
                info["url"] = u.absoluteString
            }
            info["contentType"] = mediaInfo.contentType
            info["audioTracks"] = mediaInfo.mediaTracks?.filter({(track) -> Bool in
                track.type == GCKMediaTrackType.audio
            }).map({(track) -> String in
                track.languageCode ?? "unknown"
            })
            info["subtitleTracks"] = Array(Set(mediaInfo.mediaTracks?.filter({(track) -> Bool in
                track.type == GCKMediaTrackType.text
            }).map({(track) -> String in
                track.languageCode ?? "unknown"
            }) ?? []))
            info["customData"] = mediaInfo.customData as? [String: AnyHashable?]
            if let meta = mediaInfo.metadata {
                
                info["title"] =  meta.string(forKey: kGCKMetadataKeyTitle)
                info["subtitle"] =  meta.string(forKey: kGCKMetadataKeySubtitle)
                let imgs = meta.images()
                if (imgs.count > 0){
                    if let img = imgs[0] as? GCKImage {
                        info["image"] = img.url.absoluteString
                    }
                    
                }
                
                
                
            }
        }
        return info;
    }
#endif
    
    private func isConnected() -> Bool {
#if canImport(GoogleCast)
        return sessionManager.currentCastSession?.remoteMediaClient?.connected ?? false
#else
        return false
#endif
    }
    
    private func isPlaying() -> Bool {
#if canImport(GoogleCast)
        return sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.playerState == GCKMediaPlayerState.playing
#else
        return false
#endif
    }
    
    private func addSessionListener() {
#if canImport(GoogleCast)
        sessionManager.add(self)
        if(isConnected()) {
            sessionManager.currentCastSession?.remoteMediaClient?.add(self)
            channel.invokeMethod("chromeCast#didStartSession", arguments: nil)
        }
#endif
    }
    
    private func removeSessionListener() {
#if canImport(GoogleCast)
        sessionManager.remove(self)
#endif
    }
    
    private func position() -> Int {
#if canImport(GoogleCast)
        return Int(sessionManager.currentCastSession?.remoteMediaClient?.approximateStreamPosition() ?? 0) * 1000
#else
        return 0
#endif
    }
    
    private func duration() -> Int {
#if canImport(GoogleCast)
        return Int(sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.mediaInformation?.streamDuration ?? 0) * 1000
#else
        return 0
#endif
    }
    
}

#if canImport(GoogleCast)
// MARK: - GCKSessionManagerListener
extension ChromeCastController: GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        session.remoteMediaClient?.add(self)
        channel.invokeMethod("chromeCast#didStartSession", arguments: nil)
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        session.remoteMediaClient?.remove(self)
        channel.invokeMethod("chromeCast#didEndSession", arguments: nil)
    }
}

// MARK: - GCKRequestDelegate

extension ChromeCastController: GCKRequestDelegate {
    func requestDidComplete(_ request: GCKRequest) {
        channel.invokeMethod("chromeCast#requestDidComplete", arguments: nil)
    }
    
    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        channel.invokeMethod("chromeCast#requestDidFail", arguments: ["error" : error.localizedDescription])
    }
}

// MARK: - GCKRemoteMediaClientListener
extension ChromeCastController : GCKRemoteMediaClientListener {
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        let playerStatus: GCKMediaPlayerState = mediaStatus?.playerState ?? GCKMediaPlayerState.unknown
        var retCode = 4;
        if (playerStatus == GCKMediaPlayerState.playing) {
            retCode = 1
        } else if (playerStatus == GCKMediaPlayerState.buffering) {
            retCode = 0
        } else if (playerStatus == GCKMediaPlayerState.idle && mediaStatus?.idleReason == GCKMediaPlayerIdleReason.finished) {
            retCode = 2
        }else if (playerStatus == GCKMediaPlayerState.paused) {
            retCode = 3;
        }
        channel.invokeMethod("chromeCast#didPlayerStatusUpdated", arguments: retCode)
    }
}
#endif
