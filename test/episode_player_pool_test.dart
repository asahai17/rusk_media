import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/data/services/episode_player_pool.dart';
import 'package:md_television/features/feed/domain/entities/episode_entity.dart';
import 'package:md_television/features/feed/domain/entities/feed_item.dart';
import 'package:md_television/features/feed/domain/policies/feed_composer.dart';

import 'fakes/fake_video_player_platform.dart';

String urlOf(int episodeId) => 'https://example.com/$episodeId.mp4';

bool lockedE7(int id) => id == 7;
bool nothingLocked(int id) => false;

List<EpisodeFeedItem> episodes(int count) => List.generate(
  count,
  (i) => EpisodeFeedItem(
    episode: EpisodeEntity(
      id: i + 1,
      title: 'E${i + 1}',
      description: '',
      videoUrl: urlOf(i + 1),
      posterGradientColorValues: const [0xFF000000, 0xFF000000],
    ),
  ),
);

void main() {
  const composer = FeedComposer(adEvery: 3);
  // E1 E2 E3 AD E4 E5 E6 AD E7 E8 — pages 0..9, ads at 3 and 7, E7 at 8.
  final feed = composer.compose(episodes(8));
  late FakeVideoPlayerPlatform platform;
  late EpisodePlayerPool pool;

  setUp(() {
    platform = FakeVideoPlayerPlatform.install();
    pool = EpisodePlayerPool();
  });

  tearDown(() => pool.dispose());

  /// Applies the window the bloc would derive for [page].
  Future<void> goTo(
    int page, {
    bool Function(int) isLocked = lockedE7,
    bool shouldPlay = true,
    bool muted = false,
  }) async {
    final item = feed[page];
    final active = item is EpisodeFeedItem && !isLocked(item.episode.id)
        ? item.episode.id
        : null;
    pool.apply(
      warm: composer.episodesToWarm(
        feed,
        current: page,
        radius: 1,
        isLocked: isLocked,
      ),
      activeEpisodeId: active,
      shouldPlay: shouldPlay,
      muted: muted,
    );
    await pumpEventQueue();
  }

  group('window', () {
    test('visiting E1, E2, E3 leaves exactly three controllers', () async {
      await goTo(0);
      expect(pool.liveEpisodeIds, unorderedEquals([1, 2]));
      await goTo(1);
      expect(pool.liveEpisodeIds, unorderedEquals([1, 2, 3]));
      await goTo(2);
      expect(pool.liveEpisodeIds, unorderedEquals([2, 3, 4]));
      expect(platform.sources.length, 4, reason: 'E1..E4 were created once');
    });

    test('E1 is disposed by the time E4 is reached', () async {
      for (var page = 0; page <= 4; page++) {
        await goTo(page);
      }
      final e1 = platform.playerFor(urlOf(1));
      expect(platform.disposed, contains(e1));
      expect(pool.liveEpisodeIds, unorderedEquals([3, 4, 5]));
      expect(pool.controllerFor(1), isNull);
    });

    test('an ad page keeps the episodes either side of it warm', () async {
      await goTo(3);
      expect(pool.liveEpisodeIds, unorderedEquals([3, 4]));
      expect(pool.playingEpisodeId, isNull);
    });
  });

  group('playback', () {
    test('only the active episode plays; neighbours stay paused', () async {
      await goTo(1);
      expect(pool.playingEpisodeId, 2);
      expect(platform.calls(platform.playerFor(urlOf(2))), contains('play'));
      expect(platform.calls(platform.playerFor(urlOf(1))), isNot(contains('play')));
      expect(platform.calls(platform.playerFor(urlOf(3))), isNot(contains('play')));
    });

    test('leaving an episode pauses it and rewinds it to the start', () async {
      await goTo(1);
      await goTo(2);
      final e2 = platform.calls(platform.playerFor(urlOf(2)));
      expect(e2, containsAllInOrder(['play', 'pause', 'seekTo:0']));
      expect(pool.playingEpisodeId, 3);
    });

    test('at most one controller plays at any time across the feed', () async {
      for (var page = 0; page < feed.length; page++) {
        await goTo(page, isLocked: nothingLocked);
        expect(platform.playing.length, lessThanOrEqualTo(1));
      }
      for (var page = feed.length - 1; page >= 0; page--) {
        await goTo(page, isLocked: nothingLocked);
        expect(platform.playing.length, lessThanOrEqualTo(1));
      }
      expect(platform.maxConcurrentPlaying, 1);
    });

    test('every controller loops; nothing auto-advances', () async {
      await goTo(1);
      for (final id in [1, 2, 3]) {
        expect(platform.calls(platform.playerFor(urlOf(id))), contains('setLooping:true'));
      }
      // The platform reports the clip finished; the pool leaves the page alone.
      final controller = pool.controllerFor(2)!;
      controller.value = controller.value.copyWith(
        position: controller.value.duration,
        isCompleted: true,
      );
      await pumpEventQueue();
      expect(pool.playingEpisodeId, 2);
      expect(pool.liveEpisodeIds, unorderedEquals([1, 2, 3]));
    });

    test('a controller that becomes ready while active starts on its own', () async {
      platform.createGate = Completer<void>();
      await goTo(0);
      expect(pool.statusFor(1), EpisodePlayerStatus.loading);
      expect(pool.playingEpisodeId, isNull);

      platform.createGate!.complete();
      await pumpEventQueue();
      expect(pool.statusFor(1), EpisodePlayerStatus.ready);
      expect(pool.playingEpisodeId, 1);
    });
  });

  group('background', () {
    test('pausing is not gated on what the platform reports', () async {
      await goTo(1);
      final controller = pool.controllerFor(2)!;
      // ExoPlayer waiting on audio focus: "not playing" from the plugin's
      // point of view, but it will resume by itself unless told to stop.
      controller.value = controller.value.copyWith(isPlaying: false);

      await goTo(1, shouldPlay: false);
      expect(platform.calls(platform.playerFor(urlOf(2))).last, 'pause');
      expect(pool.playingEpisodeId, isNull);
    });

    test('backgrounding keeps the position; resuming plays on', () async {
      await goTo(1);
      await goTo(1, shouldPlay: false);
      await goTo(1);
      final calls = platform.calls(platform.playerFor(urlOf(2)));
      expect(calls.where((c) => c == 'play').length, 2);
      expect(calls, isNot(contains('seekTo:0')));
    });

    test('the wakelock is held only while a video plays', () async {
      final wakelock = <bool>[];
      pool.dispose();
      pool = EpisodePlayerPool(setWakelock: (on) async => wakelock.add(on));

      await goTo(0);
      expect(wakelock, [true]);
      await goTo(0, shouldPlay: false); // user pause or background
      expect(wakelock, [true, false]);
      await goTo(0);
      expect(wakelock, [true, false, true]);
      await goTo(3); // ad page
      expect(wakelock, [true, false, true, false]);
      await goTo(8); // paywall
      expect(wakelock, [true, false, true, false]);
      await goTo(6); // E6
      expect(wakelock.last, isTrue);
      pool.dispose();
      expect(wakelock.last, isFalse);
    });

    test('a missing wakelock plugin never breaks playback', () async {
      pool.dispose();
      pool = EpisodePlayerPool(setWakelock: (_) => throw StateError('no plugin'));
      await goTo(0);
      expect(pool.playingEpisodeId, 1);
    });
  });

  group('mute', () {
    test('mute reaches every live controller and ones created later', () async {
      await goTo(0, muted: true);
      await goTo(1, muted: true); // E3 created while muted
      for (final id in [1, 2, 3]) {
        final calls = platform.calls(platform.playerFor(urlOf(id)));
        expect(calls, contains('setVolume:0.0'));
        expect(calls, isNot(contains('setVolume:1.0')));
      }
    });

    test('unmuting reaches every live controller at once', () async {
      await goTo(1, muted: true);
      await goTo(1, muted: false);
      for (final id in [1, 2, 3]) {
        expect(platform.calls(platform.playerFor(urlOf(id))).last, 'setVolume:1.0');
      }
    });

    test('the current mute is applied immediately before every play', () async {
      await goTo(0);
      await goTo(0, muted: true);
      await goTo(1, muted: true); // E2 becomes active while muted
      final e2 = platform.calls(platform.playerFor(urlOf(2)));
      final play = e2.lastIndexOf('play');
      expect(e2[play - 1], 'setVolume:0.0');
    });
  });

  group('paywall', () {
    test('the locked episode never gets a controller, in either direction', () async {
      await goTo(6); // E6
      await goTo(7); // ad
      await goTo(8); // E7, locked
      await goTo(7); // back towards E6
      await goTo(6);
      await goTo(8);
      expect(platform.wasCreated(urlOf(7)), isFalse);
      expect(pool.controllerFor(7), isNull);
      expect(pool.playingEpisodeId, isNull, reason: 'nothing plays on the paywall');
    });

    test('nothing beyond the lock warms while it holds', () async {
      await goTo(8);
      expect(pool.liveEpisodeIds, unorderedEquals([6]));
      expect(platform.wasCreated(urlOf(8)), isFalse);
    });

    test('unlocking creates and plays the locked episode', () async {
      await goTo(8);
      await goTo(8, isLocked: nothingLocked);
      expect(pool.liveEpisodeIds, unorderedEquals([6, 7, 8]));
      expect(pool.playingEpisodeId, 7);
    });
  });

  group('async guards', () {
    test('a late initialize() cannot play a controller that was evicted', () async {
      platform.createGate = Completer<void>();
      await goTo(0); // E1, E2 start initialising
      await goTo(2); // window is now E2..E4 — E1 evicted mid-initialise

      platform.createGate!.complete();
      await pumpEventQueue();

      final e1 = platform.playerFor(urlOf(1));
      expect(platform.calls(e1), isNot(contains('play')));
      expect(platform.disposed, contains(e1));
      expect(pool.liveEpisodeIds, unorderedEquals([2, 3, 4]));
      expect(pool.playingEpisodeId, 3);
    });

    test('a controller is created exactly once per window entry', () async {
      await goTo(0);
      await goTo(0);
      await goTo(1);
      await goTo(0);
      expect(platform.playersFor(urlOf(1)).length, 1);
      expect(platform.playersFor(urlOf(2)).length, 1);
    });

    test('dispose releases every controller and ignores later input', () async {
      await goTo(1);
      pool.dispose();
      await pumpEventQueue();
      expect(platform.disposed.length, 3);
      expect(platform.playing, isEmpty);
    });
  });

  group('errors', () {
    test('an init failure is surfaced instead of swallowed', () async {
      platform.failNextCreate = true;
      await goTo(0);
      expect(pool.statusFor(1), EpisodePlayerStatus.error);
      expect(pool.statusFor(2), EpisodePlayerStatus.ready);
      expect(pool.playingEpisodeId, isNull);
    });

    test('retry replaces the failed controller and plays', () async {
      platform.failNextCreate = true;
      await goTo(0);
      final failed = platform.playerFor(urlOf(1));

      await pool.retry(1);
      await pumpEventQueue();

      expect(platform.disposed, contains(failed));
      expect(platform.playersFor(urlOf(1)).length, 2);
      expect(pool.statusFor(1), EpisodePlayerStatus.ready);
      expect(pool.playingEpisodeId, 1);
    });

    test('retry is a no-op for a healthy episode', () async {
      await goTo(0);
      await pool.retry(1);
      await pumpEventQueue();
      expect(platform.playersFor(urlOf(1)).length, 1);
    });
  });
}
