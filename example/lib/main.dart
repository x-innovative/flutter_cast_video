import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cast_video/flutter_cast_video.dart';

String duration2String(Duration? dur, {showLive = 'Live'}) {
  Duration duration = dur ?? Duration();
  if (duration.inSeconds < 0)
    return showLive;
  else {
    return duration.toString().split('.').first.padLeft(8, "0");
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CastSample());
  }
}

class CastSample extends StatefulWidget {
  static const _iconSize = 50.0;

  @override
  _CastSampleState createState() => _CastSampleState();
}

class _CastSampleState extends State<CastSample> {
  late ChromeCastController _controller;
  late AirPlayController _airPlayController = AirPlayController();
  AppState _state = AppState.idle;
  bool _playing = false;
  double? _currentRate;
  String? _currentAudioTrack;
  String? _currentSubtitleTrack;
  Map<dynamic, dynamic> _mediaInfo = {};
  List<String>? _audioTracks, _subtitleTracks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plugin example app'),
        actions: <Widget>[
          AirPlayButton(
            controller: _airPlayController,
            size: 0,
            color: Colors.white,
            activeColor: Colors.amber,
            onRoutesOpening: () => print('opening'),
            onRoutesClosed: () => print('closed'),
          ),
          ChromeCastButton(
            size: 1, // can't be zero, otherwise button won't be create
            color: Colors.white,
            onButtonCreated: _onButtonCreated,
          ),
          if (Platform.isIOS)
            IconButton(
                onPressed: () => _airPlayController.performClick(),
                icon: Icon(Icons.airplay)),
          IconButton(
              onPressed: () => _controller.performClick(),
              icon: Icon(Icons.cast))
        ],
      ),
      body: Center(child: _handleState()),
    );
  }

  @override
  void dispose() {
    super.dispose();
    resetTimer();
  }

  Widget _handleState() {
    switch (_state) {
      case AppState.idle:
        resetTimer();
        return Text('ChromeCast not connected');
      case AppState.connected:
        return Text('No media loaded');
      case AppState.mediaLoaded:
        startTimer();
        return _mediaControls();
      case AppState.error:
        resetTimer();
        return Text('An error has occurred');
      default:
        return Container();
    }
  }

  Duration? position, duration;

  Widget _mediaControls() {
    return Column(children: [
      SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            _RoundIconButton(
              icon: Icons.replay_10,
              onPressed: () =>
                  _controller.seek(relative: true, interval: -10.0),
            ),
            _RoundIconButton(
                icon: _playing ? Icons.pause : Icons.play_arrow,
                onPressed: _playPause),
            _RoundIconButton(
              icon: Icons.forward_10,
              onPressed: () => _controller.seek(relative: true, interval: 10.0),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Playback rate:   "),
                DropdownButton<double>(
                  value: _currentRate,
                  items: [0.5, 0.75, 1.0, 1.25, 1.50, 1.75, 2.0]
                          .map((rate) => DropdownMenuItem(
                                value: rate,
                                child: Text(rate.toString()),
                              ))
                          .toList() ??
                      [],
                  onChanged: (rate) {
                    if (rate != null) {
                      _controller.setPlaybackRate(rate);
                    }
                  },
                )
              ],
            ),
            if (_audioTracks?.isNotEmpty == true)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Audio Track:   "),
                  DropdownButton<String>(
                    value: _currentAudioTrack,
                    items: _audioTracks
                            ?.map((lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang),
                                ))
                            .toList() ??
                        [],
                    onChanged: (lang) {
                      if (lang != null) {
                        _controller.setAudioLang(lang);
                      }
                    },
                  )
                ],
              ),
            if (_subtitleTracks?.isNotEmpty == true)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Subtitle Track:    "),
                  DropdownButton<String>(
                    value: _currentSubtitleTrack,
                    items: _subtitleTracks
                            ?.map((lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(lang),
                                ))
                            .toList() ??
                        [],
                    onChanged: (lang) {
                      if (lang != null) {
                        _controller.setSubtitleLang(lang);
                      }
                    },
                  )
                ],
              ),
          ],
        ),
      ),
      SizedBox(height: 12),
      Text(duration2String(position) + '/' + duration2String(duration)),
      SizedBox(height: 40),
      Text(JsonEncoder.withIndent("   ").convert(_mediaInfo))
    ]);
  }

  Timer? _timer;

  Future<void> _monitor() async {
    // monitor cast events
    var dur = await _controller.duration(), pos = await _controller.position();
    if (duration == null || duration!.inSeconds != dur.inSeconds) {
      setState(() {
        duration = dur;
      });
    }
    if (position == null || position!.inSeconds != pos.inSeconds) {
      setState(() {
        position = pos;
      });
    }
  }

  void resetTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void startTimer() {
    if (_timer?.isActive ?? false) {
      return;
    }
    resetTimer();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _monitor();
    });
  }

  Future<void> _playPause() async {
    final playing = await _controller.isPlaying();
    if (playing == null) return;
    if (playing) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    setState(() => _playing = !playing);
  }

  Future<void> _onButtonCreated(ChromeCastController controller) async {
    _controller = controller;
    _controller
      ..addOnSessionStartedListener(_onSessionStarted)
      ..addOnSessionEndedListener(_onSessionEnded)
      ..addOnRequestCompletedListener(_onRequestCompleted)
      ..addOnRequestFailedListener(_onRequestFailed);
  }

  Future<void> _onSessionStarted() async {
    setState(() => _state = AppState.connected);

    if ((await _controller.isConnected() ?? false) &&
        (await _controller.isPlaying() ?? false)) {
      updateMediaInfo();
    } else {
      await _controller.loadMedia(
          'https://livesim.dashif.org/dash/vod/testpic_2s/multi_subs.mpd',
          // 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          title: "TestTitle",
          subtitle: "test Sub title",
          image:
              "https://smaller-pictures.appspot.com/images/dreamstime_xxl_65780868_small.jpg");
    }
  }

  void _onSessionEnded() => setState(() => _state = AppState.idle);

  Future<void> _onRequestCompleted() async {
    updateMediaInfo();
  }

  Future<void> updateMediaInfo() async {
    final playing = await _controller.isPlaying();
    if (playing == null) return;

    final mediaInfo = await _controller.getMediaInfo();
    final rate = await _controller.getPlaybackRate();
    final audioTrack = await _controller.getAudioLang();
    final subtitleTrack = await _controller.getSubtitleLang();
    setState(() {
      _state = AppState.mediaLoaded;
      _currentRate = rate;
      _currentAudioTrack = audioTrack;
      _currentSubtitleTrack = subtitleTrack;
      _playing = playing;
      if (mediaInfo != null) {
        _mediaInfo = mediaInfo;
        _audioTracks = (mediaInfo["audioTracks"] as List<Object?>?)
            ?.where((obj) => obj != null)
            .map((obj) => obj.toString())
            .toList();
        _subtitleTracks = (mediaInfo["subtitleTracks"] as List<Object?>?)
            ?.where((obj) => obj != null)
            .map((obj) => obj.toString())
            .toSet()
            .toList();
      }
    });
  }

  Future<void> _onRequestFailed(String? error) async {
    setState(() => _state = AppState.error);
    print(error);
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
        child: Icon(icon, color: Colors.white),
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
        shape: CircleBorder(),
        onPressed: onPressed);
  }
}

enum AppState { idle, connected, mediaLoaded, error }
