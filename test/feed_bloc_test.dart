import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/data/services/episode_player_pool.dart';
import 'package:md_television/features/feed/domain/entities/feed_item.dart';
import 'package:md_television/features/feed/domain/usecases/get_feed_usecase.dart';
import 'package:md_television/features/feed/presentation/bloc/feed_bloc.dart';

import 'fakes/fake_feed_dependencies.dart';
import 'fakes/fake_video_player_platform.dart';

void main() {
  late FakeVideoPlayerPlatform platform;
  late FakeAdPreloader preloader;
  late EpisodePlayerPool pool;
  late FeedBloc bloc;

  setUp(() {
    platform = FakeVideoPlayerPlatform.install();
    preloader = FakeAdPreloader();
    pool = EpisodePlayerPool(setWakelock: (_) async {});
    bloc = FeedBloc(
      getFeedUseCase: GetFeedUseCase(FakeFeedRepository()),
      adPreloader: preloader,
      playerPool: pool,
    );
  });

  tearDown(() => bloc.close());

  Future<void> init() async {
    bloc.add(const FeedInitialized());
    await bloc.stream.first;
    await pumpEventQueue();
  }

  Future<void> send(FeedEvent event) async {
    bloc.add(event);
    await bloc.stream.first;
    await pumpEventQueue();
  }

  List<String> callsFor(int episodeId) =>
      platform.calls(platform.playerFor(urlOf(episodeId)));

  group('feed and ads', () {
    test(
      'initialises the composed feed and preloads only the near slot',
      () async {
        await init();
        expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8');
        expect(bloc.state.loadedAds, isEmpty);
        expect(preloader.requested, ['ad_1']);
      },
    );

    test('moving forward preloads the next slot within the window', () async {
      await init();
      await send(const PageChanged(4));
      expect(preloader.requested, ['ad_1', 'ad_2']);
    });

    test('ad success puts the loaded ad into state', () async {
      await init();
      preloader.succeed('ad_1');
      await bloc.stream.first;
      expect(bloc.state.loadedAds['ad_1'], same(preloader.getLoadedAd('ad_1')));
      expect(bloc.state.loadedAds.containsKey('ad_2'), isFalse);
    });

    test('an ad that loads after its slot was removed is ignored', () async {
      await init();
      preloader.fail('ad_1');
      await bloc.stream.first;
      preloader.succeed('ad_1');
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.loadedAds, isEmpty);
    });

    test('ad failure removes the slot from the feed', () async {
      await init();
      preloader.fail('ad_1');
      await bloc.stream.first;
      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
      expect(bloc.state.removedAdSlots, {'ad_1'});
      expect(bloc.state.currentPageIndex, 0);
    });

    test('removing a slot before the current page shifts the index up', () async {
      await init();
      await send(const PageChanged(5)); // E5
      preloader.fail('ad_1');
      await bloc.stream.first;
      expect(bloc.state.currentPageIndex, 4);
      expect(
        (bloc.state.feedItems[4] as EpisodeFeedItem).episode.id,
        5,
        reason: 'the user keeps looking at E5',
      );
    });

    test(
      'removing a slot after the current page leaves the index alone',
      () async {
        await init();
        await send(const PageChanged(2));
        preloader.fail('ad_2');
        await bloc.stream.first;
        expect(bloc.state.currentPageIndex, 2);
        expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 E7 E8');
      },
    );

    test('a duplicate or unknown failure is ignored', () async {
      await init();
      preloader.fail('ad_1');
      await bloc.stream.first;
      final before = bloc.state;
      preloader.fail('ad_1');
      preloader.fail('ad_9');
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, same(before));
    });

    test(
      'failure before arrival removes the slot without changing the visible episode',
      () async {
        await init();
        await send(const PageChanged(1)); // E2
        preloader.fail('ad_1');
        await bloc.stream.first;
        expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
        expect(bloc.state.currentPageIndex, 1);
        expect(bloc.state.currentEpisode?.id, 2);
        expect(bloc.state.pendingAdRemovals, isEmpty);
      },
    );

    test('failure while on the slot waits until the page has moved on', () async {
      await init();
      await send(const PageChanged(3)); // on ad_1
      preloader.fail('ad_1');
      await bloc.stream.first;
      expect(bloc.state.pendingAdRemovals, {'ad_1'});
      expect(bloc.state.isOnFailedAdSlot, isTrue);
      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8');

      // FeedPage animates to the next page; the bloc sees the scroll.
      await send(const ScrollStateChanged(isScrolling: true));
      await send(const PageChanged(4));
      expect(bloc.state.pendingAdRemovals, {'ad_1'}, reason: 'still scrolling');
      await send(const ScrollStateChanged(isScrolling: false));

      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
      expect(bloc.state.currentPageIndex, 3);
      expect(bloc.state.currentEpisode?.id, 4);
      expect(bloc.state.pendingAdRemovals, isEmpty);
    });

    test('failure during a scroll waits for the scroll to end', () async {
      await init();
      await send(const ScrollStateChanged(isScrolling: true));
      preloader.fail('ad_2');
      await bloc.stream.first;
      expect(bloc.state.pendingAdRemovals, {'ad_2'});
      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8');

      await send(const ScrollStateChanged(isScrolling: false));
      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 E7 E8');
      expect(bloc.state.pendingAdRemovals, isEmpty);
    });

    test('a repeated scroll state is not an event', () async {
      await init();
      bloc.add(const ScrollStateChanged(isScrolling: false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isScrollInProgress, isFalse);
    });

    test('closing the bloc disposes the preloader and the players', () async {
      await init();
      await bloc.close();
      await pumpEventQueue();
      expect(preloader.disposed, isTrue);
      expect(pool.liveEpisodeIds, isEmpty);
      expect(platform.disposed.length, 2);
    });
  });

  group('players', () {
    test('init warms E1 and E2 and plays E1', () async {
      await init();
      expect(pool.liveEpisodeIds, unorderedEquals([1, 2]));
      expect(pool.playingEpisodeId, 1);
    });

    test('a page change moves the window and the playing episode', () async {
      await init();
      await send(const PageChanged(1));
      expect(pool.liveEpisodeIds, unorderedEquals([1, 2, 3]));
      expect(pool.playingEpisodeId, 2);
      expect(callsFor(1), containsAllInOrder(['play', 'pause', 'seekTo:0']));
    });

    test('a removed slot keeps the same episode playing', () async {
      await init();
      await send(const PageChanged(5)); // E5
      preloader.fail('ad_1');
      await bloc.stream.first;
      await pumpEventQueue();
      expect(pool.playingEpisodeId, 5);
      expect(pool.liveEpisodeIds, unorderedEquals([4, 5, 6]));
    });

    test('tapping pauses the current episode; the next page clears it', () async {
      await init();
      await send(const PlaybackToggled());
      expect(bloc.state.isUserPaused, isTrue);
      expect(pool.playingEpisodeId, isNull);
      expect(callsFor(1), containsAllInOrder(['play', 'pause']));

      await send(const PageChanged(1));
      expect(bloc.state.isUserPaused, isFalse);
      expect(pool.playingEpisodeId, 2);
    });

    test('the locked episode has no controller until unlock', () async {
      await init();
      await send(const PageChanged(8)); // E7
      expect(platform.wasCreated(urlOf(7)), isFalse);
      expect(platform.wasCreated(urlOf(8)), isFalse);
      expect(pool.playingEpisodeId, isNull);

      await send(const PaywallUnlockRequested());
      expect(pool.playingEpisodeId, 7);
      expect(pool.liveEpisodeIds, unorderedEquals([6, 7, 8]));
    });

    test('the lock is a property of the episode and lifts on unlock', () async {
      await init();
      expect(bloc.state.lockedEpisodeId, 7);
      expect(bloc.state.isEpisodeLocked(7), isTrue);
      expect(bloc.state.isEpisodeLocked(6), isFalse);
      expect(bloc.state.lockedPageIndex, 8);

      await send(const PaywallUnlockRequested());
      expect(bloc.state.isEpisodeLocked(7), isFalse);
      expect(bloc.state.lockedPageIndex, isNull);
    });

    test('mute follows state', () async {
      await init();
      await send(const MuteToggled());
      expect(bloc.state.isMuted, isTrue);
      expect(callsFor(1), contains('setVolume:0.0'));
    });

  });

  group('background', () {
    int plays(int episodeId) =>
        callsFor(episodeId).where((call) => call == 'play').length;

    test('backgrounding pauses the active episode', () async {
      await init();
      await send(const AppVisibilityChanged(isForeground: false));
      expect(bloc.state.isAppInForeground, isFalse);
      expect(pool.playingEpisodeId, isNull);
      expect(callsFor(1), containsAllInOrder(['play', 'pause']));
    });

    test('resuming plays again', () async {
      await init();
      await send(const AppVisibilityChanged(isForeground: false));
      await send(const AppVisibilityChanged(isForeground: true));
      expect(pool.playingEpisodeId, 1);
      expect(plays(1), 2);
    });

    test('a user pause survives a background round trip', () async {
      await init();
      await send(const PlaybackToggled());
      await send(const AppVisibilityChanged(isForeground: false));
      await send(const AppVisibilityChanged(isForeground: true));
      expect(bloc.state.isUserPaused, isTrue);
      expect(pool.playingEpisodeId, isNull);
      expect(plays(1), 1, reason: 'no auto-resume after a user pause');

      await send(const PlaybackToggled());
      expect(pool.playingEpisodeId, 1);
    });
  });
}
