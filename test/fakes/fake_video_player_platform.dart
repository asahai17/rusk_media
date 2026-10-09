import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// In-memory [VideoPlayerPlatform]. Records every call per player so tests can
/// assert on create/play/pause/dispose ordering without a device.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, List<String>> _calls = {};
  final Map<int, String> sources = {};
  final Map<int, StreamController<VideoEvent>> _events = {};
  final Set<int> playing = {};
  final Set<int> disposed = {};
  int maxConcurrentPlaying = 0;
  int _nextId = 0;

  /// While set, [createWithOptions] waits on it, so a test can evict a player
  /// in the middle of `initialize()`.
  Completer<void>? createGate;

  /// The next created player reports an initialisation error.
  bool failNextCreate = false;

  static FakeVideoPlayerPlatform install() {
    final platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    return platform;
  }

  List<String> calls(int playerId) => _calls[playerId] ?? const [];

  /// Every player created for [videoUrl], oldest first.
  List<int> playersFor(String videoUrl) => [
    for (final entry in sources.entries)
      if (entry.value == videoUrl) entry.key,
  ];

  /// The most recent player for [videoUrl]; throws if none was created.
  int playerFor(String videoUrl) => playersFor(videoUrl).last;

  bool wasCreated(String videoUrl) => playersFor(videoUrl).isNotEmpty;

  void _record(int playerId, String call) =>
      _calls.putIfAbsent(playerId, () => []).add(call);

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) => createWithOptions(
    VideoCreationOptions(
      dataSource: dataSource,
      viewType: VideoViewType.textureView,
    ),
  );

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final gate = createGate;
    if (gate != null) await gate.future;

    final id = _nextId++;
    sources[id] = options.dataSource.uri ?? '';
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    if (failNextCreate) {
      failNextCreate = false;
      events.addError(
        PlatformException(code: 'VideoError', message: 'fake init failure'),
      );
    } else {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(16, 9),
          duration: const Duration(seconds: 10),
        ),
      );
    }
    _record(id, 'create');
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]?.stream ?? const Stream.empty();

  @override
  Future<void> dispose(int playerId) async {
    _record(playerId, 'dispose');
    playing.remove(playerId);
    disposed.add(playerId);
    // Not awaited: a single-subscription controller whose listener already
    // cancelled never completes its close() future.
    unawaited(_events.remove(playerId)?.close());
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      _record(playerId, 'setLooping:$looping');

  @override
  Future<void> play(int playerId) async {
    _record(playerId, 'play');
    playing.add(playerId);
    maxConcurrentPlaying = math.max(maxConcurrentPlaying, playing.length);
  }

  @override
  Future<void> pause(int playerId) async {
    _record(playerId, 'pause');
    playing.remove(playerId);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      _record(playerId, 'setVolume:$volume');

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      _record(playerId, 'seekTo:${position.inMilliseconds}');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}
