part of flutter_cast_video;

final ChromeCastPlatform _chromeCastPlatform = ChromeCastPlatform.instance;

/// Callback method for when a request has failed.
typedef void OnRequestFailed(String? error);

enum CastPlayerStatus { buffering, playing, idle, paused, unknown }

typedef OnPlayerStatusUpdated = void Function(CastPlayerStatus status);

/// Controller for a single ChromeCastButton instance running on the host platform.
class ChromeCastController {
  /// The id for this controller
  final int id;

  /// Called when a cast session has started.
  final Set<VoidCallback> _onSessionStartedListeners = {};

  /// Called when a cast session has ended.
  final Set<VoidCallback> _onSessionEndedListeners = {};

  /// Called when a cast request has successfully completed.
  final Set<VoidCallback> _onRequestCompletedListeners = {};

  /// Called when a cast request has failed.
  final Set<OnRequestFailed> _onRequestFailedListeners = {};

  /// Called when player status updated
  final Set<OnPlayerStatusUpdated> _onPlayerStatusUpdatedListeners = {};

  ChromeCastController._({required this.id});

  /// Initialize control of a [ChromeCastButton] with [id].
  static Future<ChromeCastController> init(int id) async {
    await _chromeCastPlatform.init(id);
    return ChromeCastController._(id: id)
      ..addSessionListener();
  }

  /// Add listener for receive callbacks.
  Future<void> addSessionListener() {
    _chromeCastPlatform
      ..onSessionStarted(id: id).listen(notifySessionStartedListeners)
      ..onSessionEnded(id: id).listen(notifySessionEndedListeners)
      ..onRequestCompleted(id: id).listen(notifyRequestCompletedListeners)
      ..onRequestFailed(id: id).listen(notifyRequestFailedListeners)
      ..onPlayerStatusUpdated(id: id).listen(notifyPlayerStatusUpdatedListeners
      );

    return _chromeCastPlatform.addSessionListener(id: id);
  }


  @visibleForTesting
  void notifySessionStartedListeners(_) =>
      _onSessionStartedListeners.forEach((listener) => listener());

  @visibleForTesting
  void notifySessionEndedListeners(_) =>
      _onSessionEndedListeners.forEach((listener) => listener());

  @visibleForTesting
  void notifyRequestCompletedListeners(_) =>
      _onRequestCompletedListeners.forEach((listener) => listener());

  @visibleForTesting
  void notifyRequestFailedListeners(event) =>
      _onRequestFailedListeners
          .forEach((listener) => listener(event.error));

  @visibleForTesting
  void notifyPlayerStatusUpdatedListeners(event) =>
      _onPlayerStatusUpdatedListeners.forEach((listener) =>
          listener(
              CastPlayerStatus.values.firstWhere(
                      (status) => status.index == event.status,
                  orElse: () => CastPlayerStatus.unknown)));


  /// Remove listener for receive callbacks.
  Future<void> removeSessionListener() {
    _onSessionStartedListeners.clear();
    _onSessionEndedListeners.clear();
    _onRequestCompletedListeners.clear();
    _onRequestFailedListeners.clear();
    _onPlayerStatusUpdatedListeners.clear();

    return _chromeCastPlatform.removeSessionListener(id: id);
  }

  void addOnSessionStartedListener(VoidCallback listener) =>
      _onSessionStartedListeners.add(listener);

  void removeOnSessionStartedListener(VoidCallback listener) =>
      _onSessionStartedListeners.remove(listener);

  void addOnSessionEndedListener(VoidCallback listener) =>
      _onSessionEndedListeners.add(listener);

  void removeOnSessionEndedListener(VoidCallback listener) =>
      _onSessionEndedListeners.remove(listener);

  void addOnRequestCompletedListener(VoidCallback listener) =>
      _onRequestCompletedListeners.add(listener);

  void removeOnRequestCompletedListener(VoidCallback listener) =>
      _onRequestCompletedListeners.remove(listener);

  void addOnRequestFailedListener(OnRequestFailed listener) =>
      _onRequestFailedListeners.add(listener);

  void removeOnRequestFailedListener(OnRequestFailed listener) =>
      _onRequestFailedListeners.remove(listener);

  void addOnPlayerStatusUpdatedListeners(OnPlayerStatusUpdated listener) =>
      _onPlayerStatusUpdatedListeners.add(listener);

  void removeOnPlayerStatusUpdatedListeners(OnPlayerStatusUpdated listener) =>
      _onPlayerStatusUpdatedListeners.remove(listener);

  /// Load a new media by providing an [url].
  Future<void> loadMedia(String url,
      {String title = '',
        String subtitle = '',
        String image = '',
        Map<String, dynamic> customData = const {},
        bool? live}) {
    return _chromeCastPlatform.loadMedia(url, title, subtitle, image,
        id: id, customData: customData, live: live);
  }

  /// Plays the video playback.
  Future<void> play() {
    return _chromeCastPlatform.play(id: id);
  }

  /// Pauses the video playback.
  Future<void> pause() {
    return _chromeCastPlatform.pause(id: id);
  }

  /// If [relative] is set to false sets the video position to an [interval] from the start.
  ///
  /// If [relative] is set to true sets the video position to an [interval] from the current position.
  Future<void> seek({bool relative = false, double interval = 10.0}) {
    return _chromeCastPlatform.seek(relative, interval, id: id);
  }

  /// Set volume 0-1
  Future<void> setVolume({double volume = 0}) {
    return _chromeCastPlatform.setVolume(volume, id: id);
  }

  /// Get current volume
  Future<Map<dynamic, dynamic>?> getMediaInfo() {
    return _chromeCastPlatform.getMediaInfo(id: id);
  }

  /// Get current volume
  Future<double> getVolume() {
    return _chromeCastPlatform.getVolume(id: id);
  }

  /// Stop the current video.
  Future<void> stop() {
    return _chromeCastPlatform.stop(id: id);
  }

  /// Returns `true` when a cast session is connected, `false` otherwise.
  Future<bool?> isConnected() {
    return _chromeCastPlatform.isConnected(id: id);
  }

  /// End current session
  Future<void> endSession() {
    return _chromeCastPlatform.endSession(id: id);
  }

  /// Returns `true` when a cast session is playing, `false` otherwise.
  Future<bool?> isPlaying() {
    return _chromeCastPlatform.isPlaying(id: id);
  }

  /// Returns current position.
  Future<Duration> position() {
    return _chromeCastPlatform.position(id: id);
  }

  /// Returns video duration.
  Future<Duration> duration() {
    return _chromeCastPlatform.duration(id: id);
  }

  Future<String?> getSubtitleLang() {
    return _chromeCastPlatform.getSubtitleTrack(id: id);
  }

  Future<void> setSubtitleLang(String lang) {
    return _chromeCastPlatform.setSubtitleTrack(lang, id: id);
  }

  Future<String?> getAudioLang() {
    return _chromeCastPlatform.getAudioTrack(id: id);
  }

  Future<void> setAudioLang(String lang) {
    return _chromeCastPlatform.setAudioTrack(lang, id: id);
  }

  Future<double?> getPlaybackRate() {
    return _chromeCastPlatform.getPlaybackRate(id: id);
  }

  Future<void> setPlaybackRate(double rate) {
    return _chromeCastPlatform.setPlaybackRate(rate, id: id);
  }

  Future<void> performClick() {
    return _chromeCastPlatform.performClick(id: id);
  }
}
