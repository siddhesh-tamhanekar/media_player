import 'dart:ui';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:media_player/data_sources.dart';

class MediaPlayerPlugin {
  static MethodChannel _channel = new MethodChannel("com.example.media_player");

  /// create new video player need to think about videoplayer constructor.
  static MediaPlayer create(
      {bool isBackground = false, bool showNotification = false}) {
    MediaPlayer player = MediaPlayer(_channel, isBackground, showNotification);

    return player;
  }
}

/// The controller which controls the whole videoplayer.
class MediaPlayer {
  String name;
  StreamSubscription<dynamic> _eventSubscription;
  MethodChannel _channel;

  Timer _timer;
  bool _isDisposed = false;
  int _textureId;

  ValueNotifier<VideoPlayerValue> valueNotifier;

  bool isBackground = false;
  bool showNotification;
  _VideoAppLifeCycleObserver _lifeCycleObserver;

  /// Constructor.
  MediaPlayer(this._channel, this.isBackground, this.showNotification) {
    valueNotifier =
        ValueNotifier(VideoPlayerValue(duration: null, isLoading: true));
  }

  Future<void> initialize() async {
    _lifeCycleObserver = _VideoAppLifeCycleObserver(this);

    _lifeCycleObserver.initialize();

    final Map<dynamic, dynamic> response =
        await _channel.invokeMethod("create", _createArgs());
    this._textureId = response['textureId'];

    EventChannel eventChannel =
        new EventChannel("media_player_event_channel$_textureId");

    _eventSubscription = eventChannel
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);
  }

  DurationRange toDurationRange(dynamic value) {
    final List<dynamic> pair = value;
    return DurationRange(
      Duration(milliseconds: pair[0]),
      Duration(milliseconds: pair[1]),
    );
  }

  void toggleFullScreen() {
    bool isFullScreen = !valueNotifier.value.isFullScreen;
    print("Toogle Full screen called $isFullScreen");
    valueNotifier.value =
        valueNotifier.value.copyWith(isFullScreen: isFullScreen);
  }

  void eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    print(map);
    switch (map['event']) {
      case 'initialized':
        print("intialized event came");
        print(map);

        valueNotifier.value = valueNotifier.value.copyWith(
            isLoading: false,
            duration: Duration(milliseconds: map['duration']),
            size: Size(map['width']?.toDouble() ?? 0.0,
                map['height']?.toDouble() ?? 0.0),
            currentIndex: map['current_index'] ?? 0);

        _applyLooping();
        _applyVolume();
        _applyPlayPause();
        break;
      case 'paused':
        valueNotifier.value = valueNotifier.value.copyWith(isPlaying: false);
        _timer?.cancel();
        break;
      case 'play':
        valueNotifier.value =
            valueNotifier.value.copyWith(isPlaying: true, isLoading: false);
        startTimer();
        break;
      case 'completed':
        valueNotifier.value = valueNotifier.value.copyWith(isPlaying: false);
        _timer?.cancel();
        break;
      case 'bufferingUpdate':
        final List<dynamic> values = map['values'];
        valueNotifier.value = valueNotifier.value.copyWith(
          isLoading: true,
          buffered: values.map<DurationRange>(toDurationRange).toList(),
        );
        break;
      case 'bufferingStart':
        valueNotifier.value =
            valueNotifier.value.copyWith(isBuffering: true, isLoading: true);
        break;
      case 'bufferingEnd':
        valueNotifier.value =
            valueNotifier.value.copyWith(isBuffering: false, isLoading: false);
        break;
    }
  }

  void errorListener(Object obj) {
    final PlatformException e = obj;
    valueNotifier.value = VideoPlayerValue.erroneous(e.message,
        valueNotifier.value.source, valueNotifier.value.currentIndex);
    _timer?.cancel();
  }

  Map _createArgs([Map args]) {
    if (args == null) args = {};
    args.addAll({
      "textureId": _textureId,
      "isBackground": isBackground,
      "showNotification": showNotification
    });
    return args;
  }

  get textureId => _textureId;

  Future<void> setSource(MediaFile source) async {
    valueNotifier.value =
        valueNotifier.value.copyWith(isLoading: true, source: source);
    await _channel.invokeMethod(
        "setSource", _createArgs({"source": source.toMap()}));
  }

  Future<void> setPlaylist(Playlist playlist) async {
    valueNotifier.value =
        valueNotifier.value.copyWith(isLoading: true, source: playlist);

    // facing some issues while using the createArgs method.
    await _channel.invokeMethod("setPlaylist", {
      "textureId": _textureId,
      "isBackground": isBackground,
      "showNotification": showNotification,
      "playlist": playlist.toMap()
    });
  }

  bool playNext() {
    if (valueNotifier.value.source is Playlist) {
      int i = valueNotifier.value.currentIndex + 1;
      i = i.clamp(0, valueNotifier.value.source.count);

      valueNotifier.value =
          valueNotifier.value.copyWith(currentIndex: i, isLoading: true);
      _channel.invokeMethod("seekTo", _createArgs({"location": 0, 'index': i}));
      return true;
    }
    return false;
  }

  playPrev() {
    if (valueNotifier.value.source is Playlist) {
      int i = valueNotifier.value.currentIndex - 1;
      i = i.clamp(0, valueNotifier.value.source.count);

      valueNotifier.value =
          valueNotifier.value.copyWith(currentIndex: i, isLoading: true);
      _channel.invokeMethod("seekTo", _createArgs({"location": 0, 'index': i}));
      return true;
    }
    return false;
  }

  playAt(int i) {
    if (valueNotifier.value.source is Playlist) {
      i = i.clamp(0, valueNotifier.value.source.count);

      valueNotifier.value =
          valueNotifier.value.copyWith(currentIndex: i, isLoading: true);
      _channel.invokeMethod("seekTo", _createArgs({"location": 0, 'index': i}));
      return true;
    }
    return false;
  }

  bool seek(int moment, [int index = -1]) {
    valueNotifier.value = valueNotifier.value.copyWith(isLoading: true);
    _channel.invokeMethod(
        "seekTo", _createArgs({"location": moment, 'index': index}));

    return true;
  }

  bool retry() {
    print("Retryig..");
    valueNotifier.value = valueNotifier.value.copyWith(errorDescription: "");
    print("after Retryig..  {$valueNotifier.value}");

    _channel.invokeMethod("retry", _createArgs({}));
    return true;
  }

  bool fastForward(int seconds) {
    int current = valueNotifier.value.position.inSeconds;
    int seekTo = current + seconds;
    print("fast forward to $current, $seekTo");
    return this.seek(seekTo * 1000);
  }

  bool rewind(int seconds) {
    int current = valueNotifier.value.position.inSeconds;
    int seekTo = current - seconds;
    if (seekTo < 0) seekTo = 0;
    print("fast forward to $current, $seekTo");
    return this.seek(seekTo * 1000);
  }

  Future<void> play() async {
    print("Play called");
    valueNotifier.value =
        valueNotifier.value.copyWith(isPlaying: true, errorDescription: null);
    await _applyPlayPause();
  }

  Future<void> setLooping(bool looping) async {
    valueNotifier.value = valueNotifier.value.copyWith(isLooping: looping);
    await _applyLooping();
  }

  Future<void> togglePlayPause() async {
    valueNotifier.value =
        valueNotifier.value.copyWith(isPlaying: !valueNotifier.value.isPlaying);
    await _applyPlayPause();
  }

  Future<void> pause() async {
    valueNotifier.value = valueNotifier.value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> _applyLooping() async {
    if (!valueNotifier.value.initialized || _isDisposed) {
      return;
    }
    _channel.invokeMethod(
      'setLooping',
      _createArgs({'looping': valueNotifier.value.isLooping}),
    );
  }

  Future<void> _applyPlayPause() async {
    if (!valueNotifier.value.initialized || _isDisposed) {
      await _channel.invokeMethod(
        'play',
        _createArgs(),
      );
    }
    if (valueNotifier.value.isPlaying) {
      await _channel.invokeMethod(
        'play',
        _createArgs(),
      );
      await startTimer();
    } else {
      _timer?.cancel();
      await _channel.invokeMethod(
        'pause',
        _createArgs(),
      );
    }
  }

  Future startTimer() async {
    _timer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (Timer timer) async {
        if (_isDisposed) {
          return;
        }
        final Duration newPosition = await position;
        if (_isDisposed) {
          return;
        }
        valueNotifier.value =
            valueNotifier.value.copyWith(position: newPosition);
      },
    );
  }

  Future<void> _applyVolume() async {
    if (!valueNotifier.value.initialized || _isDisposed) {
      return;
    }
    await _channel.invokeMethod(
      'setVolume',
      _createArgs({'volume': valueNotifier.value.volume}),
    );
  }

  /// The position in the current video.
  Future<Duration> get position async {
    if (_isDisposed) {
      return null;
    }
    return Duration(
      milliseconds: await _channel.invokeMethod('position', _createArgs()),
    );
  }

  Future<void> setVolume(double volume) async {
    valueNotifier.value =
        valueNotifier.value.copyWith(volume: volume.clamp(0.0, 1.0));
    await _applyVolume();
  }

  Future<void> dispose() async {
    if (_isDisposed || !valueNotifier.value.initialized) return;
    _eventSubscription.cancel();
    _isDisposed = true;
    _timer.cancel();
    await _channel.invokeMethod("dispose", _createArgs());
  }
}

class DurationRange {
  DurationRange(this.start, this.end);

  final Duration start;
  final Duration end;

  double startFraction(Duration duration) {
    return start.inMilliseconds / duration.inMilliseconds;
  }

  double endFraction(Duration duration) {
    return end.inMilliseconds / duration.inMilliseconds;
  }

  @override
  String toString() => '$runtimeType(start: $start, end: $end)';
}

class VideoPlayerValue {
  VideoPlayerValue(
      {@required this.duration,
      this.size,
      this.position = const Duration(),
      this.buffered = const <DurationRange>[],
      this.isPlaying = false,
      this.isLooping = false,
      this.isLoading = false,
      this.isBuffering = false,
      this.volume = 1.0,
      this.errorDescription,
      this.source,
      this.currentIndex = 0,
      this.isFullScreen = false});

  VideoPlayerValue.uninitialized() : this(duration: null);

  VideoPlayerValue.erroneous(
      String errorDescription, Source source, int currentIndex)
      : this(
            duration: null,
            errorDescription: errorDescription,
            source: source,
            currentIndex: currentIndex);

  /// The total duration of the video.
  ///
  /// Is null when [initialized] is false.
  final Duration duration;

  /// The current playback position.
  final Duration position;

  /// The currently buffered ranges.
  final List<DurationRange> buffered;

  /// True if the video is playing. False if it's paused.
  final bool isPlaying;

  /// True if the video is looping.
  final bool isLooping;

  final bool isLoading;
  final Source source;
  final int currentIndex;

  /// True if the video is currently buffering.
  final bool isBuffering;
  final bool isFullScreen;

  /// The current volume of the playback.
  final double volume;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is [null].
  final String errorDescription;

  /// The [size] of the currently loaded video.
  ///
  /// Is null when [initialized] is false.
  final Size size;

  bool get initialized => duration != null;
  bool get hasError => errorDescription != null;
  double get aspectRatio {
    if (size == null || size.width == null) {
      return 1.5;
    }
    return size.width / size.height;
  }

  MediaFile get getCurrrentMediaFile {
    if (source is Playlist) return (source as Playlist).contents[currentIndex];
    return source;
  }

  bool get next {
    if (source is Playlist && (currentIndex + 1) < source.count) {
      return true;
    }
    return false;
  }

  bool get prev {
    if (source is Playlist && (currentIndex - 1) >= 0) {
      // print()
      return true;
    }
    return false;
  }

  VideoPlayerValue copyWith({
    Duration duration,
    Size size,
    Duration position,
    List<DurationRange> buffered,
    bool isPlaying,
    bool isLooping,
    bool isBuffering,
    bool isLoading,
    Source source,
    int currentIndex,
    bool isFullScreen,
    double volume,
    String errorDescription,
  }) {
    return VideoPlayerValue(
      duration: duration ?? this.duration,
      size: size ?? this.size,
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      isLoading: isLoading ?? this.isLoading,
      volume: volume ?? this.volume,
      source: source ?? this.source,
      currentIndex: currentIndex ?? this.currentIndex,
      errorDescription: errorDescription ?? this.errorDescription,
      isFullScreen: isFullScreen ?? this.isFullScreen,
    );
  }

  @override
  String toString() {
    return '$runtimeType('
        'duration: $duration, '
        'size: $size, '
        'position: $position, '
        'buffered: [${buffered.join(', ')}], '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering'
        'volume: $volume, '
        'source: $source, '
        'loading: $isLoading, '
        'index: $currentIndex, '
        'errorDescription: $errorDescription)'
        'isFullScreen: $isFullScreen)';
  }
}

class _VideoAppLifeCycleObserver extends Object with WidgetsBindingObserver {
  _VideoAppLifeCycleObserver(this._controller);

  bool _wasPlayingBeforePause = false;
  final MediaPlayer _controller;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("change application life cycle $state");
    switch (state) {
      case AppLifecycleState.paused:
        if (!_controller.isBackground) {
          _wasPlayingBeforePause = _controller.valueNotifier.value.isPlaying;
          _controller.pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause) {
          _controller.play();
        }
        break;
      case AppLifecycleState.suspending:
        _controller.dispose();
        break;
      default:
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
