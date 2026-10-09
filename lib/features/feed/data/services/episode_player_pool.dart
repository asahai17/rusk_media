import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/entities/episode_entity.dart';

enum EpisodePlayerStatus { loading, ready, error }

/// Owns every [VideoPlayerController] in the feed.
///
/// [apply] is the only input: it names the episodes that must be warm and the
/// one that may play; anything else is disposed. Playback is intent-based —
/// the pool tracks what it last told each controller, never
/// `controller.value.isPlaying`, because ExoPlayer can report not-playing
/// while waiting on audio focus and then resume on its own.
///
/// Every async continuation re-checks that its controller is still the one
/// registered for the episode, so a late `initialize()` can never touch a
/// controller that has already been evicted.
///
/// The pool also owns the wakelock: the screen stays awake only while it has
/// told a controller to play.
class EpisodePlayerPool extends ChangeNotifier {
  EpisodePlayerPool({Future<void> Function(bool enabled)? setWakelock})
    : _setWakelock = setWakelock ?? _toggleWakelockPlus;

  final Future<void> Function(bool enabled) _setWakelock;
  final Map<int, _PlayerEntry> _entries = {};
  int? _activeId;
  bool _shouldPlay = false;
  bool _muted = false;
  bool _wakelockOn = false;
  bool _disposed = false;

  static Future<void> _toggleWakelockPlus(bool enabled) =>
      WakelockPlus.toggle(enable: enabled);

  VideoPlayerController? controllerFor(int episodeId) =>
      _entries[episodeId]?.controller;

  EpisodePlayerStatus? statusFor(int episodeId) => _entries[episodeId]?.status;

  Iterable<int> get liveEpisodeIds => _entries.keys;

  int? get playingEpisodeId {
    for (final entry in _entries.values) {
      if (entry.isPlaying) return entry.id;
    }
    return null;
  }

  /// Reconciles the pool with the desired window. Idempotent and cheap:
  /// nothing is touched unless its desired state changed.
  void apply({
    required List<EpisodeEntity> warm,
    required int? activeEpisodeId,
    required bool shouldPlay,
    required bool muted,
  }) {
    if (_disposed) return;

    final wanted = {for (final episode in warm) episode.id};
    for (final id in _entries.keys.where((id) => !wanted.contains(id)).toList()) {
      _evict(id);
    }
    for (final episode in warm) {
      if (!_entries.containsKey(episode.id)) _create(episode);
    }

    final mutedChanged = muted != _muted;
    _activeId = activeEpisodeId;
    _shouldPlay = shouldPlay;
    _muted = muted;

    // Pause before play, so two players are never audible at once.
    _PlayerEntry? active;
    for (final entry in _entries.values) {
      if (mutedChanged) unawaited(entry.controller.setVolume(_volume));
      if (entry.id == _activeId) {
        active = entry;
      } else {
        _syncPlayback(entry);
      }
    }
    if (active != null) _syncPlayback(active);
    _syncWakelock();
  }

  /// Replaces a failed controller with a fresh one. No-op unless the episode
  /// is live and in the error state.
  Future<void> retry(int episodeId) async {
    final failed = _entries[episodeId];
    if (failed == null || failed.status != EpisodePlayerStatus.error) return;
    _evict(episodeId);
    _create(failed.episode);
    _syncWakelock();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final id in _entries.keys.toList()) {
      _evict(id);
    }
    _syncWakelock();
    super.dispose();
  }

  double get _volume => _muted ? 0.0 : 1.0;

  void _create(EpisodeEntity episode) {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(episode.videoUrl),
      // The pool is the single owner of background pause/resume; the plugin's
      // own lifecycle observer would be a second one.
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    final entry = _PlayerEntry(episode, controller);
    _entries[episode.id] = entry;
    unawaited(_initialize(entry));
  }

  Future<void> _initialize(_PlayerEntry entry) async {
    final controller = entry.controller;
    // Both are stored on the value now and pushed to the platform by the
    // plugin as soon as the player is initialised.
    unawaited(controller.setLooping(true));
    unawaited(controller.setVolume(_volume));
    try {
      await controller.initialize();
    } catch (e) {
      if (!_isCurrent(entry)) return;
      debugPrint('episode ${entry.id} init failed: $e');
      entry.status = EpisodePlayerStatus.error;
      notifyListeners();
      return;
    }
    if (!_isCurrent(entry)) return; // evicted mid-initialise; already disposed
    entry.status = EpisodePlayerStatus.ready;
    _syncPlayback(entry);
    _syncWakelock();
    notifyListeners();
  }

  void _syncWakelock() {
    final on = !_disposed && _entries.values.any((entry) => entry.isPlaying);
    if (on == _wakelockOn) return;
    _wakelockOn = on;
    // A missing plugin must never break playback.
    try {
      unawaited(
        _setWakelock(on).catchError((Object e) => debugPrint('wakelock: $e')),
      );
    } catch (e) {
      debugPrint('wakelock: $e');
    }
  }

  bool _isCurrent(_PlayerEntry entry) =>
      !_disposed && identical(_entries[entry.id], entry);

  void _evict(int episodeId) {
    final entry = _entries.remove(episodeId);
    if (entry == null) return;
    entry.isPlaying = false;
    unawaited(entry.controller.dispose());
  }

  void _syncPlayback(_PlayerEntry entry) {
    final wantsPlay =
        entry.id == _activeId &&
        _shouldPlay &&
        entry.status == EpisodePlayerStatus.ready;
    if (wantsPlay == entry.isPlaying) return;
    entry.isPlaying = wantsPlay;

    final controller = entry.controller;
    if (wantsPlay) {
      unawaited(controller.setVolume(_volume));
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
      // A neighbour that is no longer current waits at its first frame.
      if (entry.id != _activeId) unawaited(controller.seekTo(Duration.zero));
    }
  }
}

class _PlayerEntry {
  _PlayerEntry(this.episode, this.controller);

  final EpisodeEntity episode;
  final VideoPlayerController controller;
  EpisodePlayerStatus status = EpisodePlayerStatus.loading;
  bool isPlaying = false;

  int get id => episode.id;
}
