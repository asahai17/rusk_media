import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/data/services/episode_player_pool.dart';
import 'package:md_television/features/feed/domain/usecases/get_feed_usecase.dart';
import 'package:md_television/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:md_television/features/feed/presentation/pages/feed_page.dart';

import 'fakes/fake_feed_dependencies.dart';
import 'fakes/fake_video_player_platform.dart';

void main() {
  late FakeAdPreloader preloader;
  late EpisodePlayerPool pool;
  late FeedBloc bloc;

  setUp(() {
    FakeVideoPlayerPlatform.install();
  });

  /// Everything is built inside the test body so the bloc's stream work runs
  /// in the fake-async zone and is pumped with the tree.
  Future<void> pumpFeed(WidgetTester tester) async {
    preloader = FakeAdPreloader();
    pool = EpisodePlayerPool(setWakelock: (_) async {});
    bloc = FeedBloc(
      getFeedUseCase: GetFeedUseCase(FakeFeedRepository()),
      adPreloader: preloader,
      playerPool: pool,
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<FeedBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FeedPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> swipeUp(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, -400), 1500);
    await settle(tester);
  }

  double shownPage(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  Future<void> tearDownFeed(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    pool.dispose();
    await tester.pump();
  }

  testWidgets('swiping moves one page at a time and plays that episode', (
    tester,
  ) async {
    await pumpFeed(tester);
    expect(bloc.state.currentPageIndex, 0);
    expect(pool.playingEpisodeId, 1);

    await swipeUp(tester);
    expect(bloc.state.currentPageIndex, 1);
    expect(shownPage(tester), 1.0);
    expect(pool.playingEpisodeId, 2);
    expect(bloc.state.isScrollInProgress, isFalse);

    await tearDownFeed(tester);
  });

  testWidgets(
    'a failure before arrival removes the slot without moving the visible page',
    (tester) async {
      await pumpFeed(tester);
      await swipeUp(tester); // E2

      preloader.fail('ad_1');
      await tester.pump();
      await settle(tester);

      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
      expect(bloc.state.currentPageIndex, 1);
      expect(shownPage(tester), 1.0);
      expect(pool.playingEpisodeId, 2);

      await tearDownFeed(tester);
    },
  );

  testWidgets(
    'a failure while on the slot advances to the next episode, then removes it',
    (tester) async {
      await pumpFeed(tester);
      await swipeUp(tester);
      await swipeUp(tester);
      await swipeUp(tester); // on ad_1
      expect(bloc.state.currentPageIndex, 3);
      expect(pool.playingEpisodeId, isNull);

      preloader.fail('ad_1');
      await tester.pump();
      await settle(tester);

      expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
      expect(bloc.state.currentPageIndex, 3);
      expect(bloc.state.currentEpisode?.id, 4);
      expect(shownPage(tester), 3.0);
      expect(pool.playingEpisodeId, 4);
      expect(bloc.state.pendingAdRemovals, isEmpty);

      await tearDownFeed(tester);
    },
  );

  testWidgets(
    'a failure behind the current page shifts the controller in place',
    (tester) async {
      await pumpFeed(tester);
      for (var i = 0; i < 4; i++) {
        await swipeUp(tester);
      }
      expect(bloc.state.currentEpisode?.id, 4);
      expect(shownPage(tester), 4.0);

      preloader.fail('ad_1');
      await tester.pump();
      await settle(tester);

      expect(bloc.state.currentPageIndex, 3);
      expect(bloc.state.currentEpisode?.id, 4);
      expect(shownPage(tester), 3.0);
      expect(pool.playingEpisodeId, 4);

      await tearDownFeed(tester);
    },
  );

  testWidgets('a fling past E7 does not move while locked, and does after unlock', (
    tester,
  ) async {
    await pumpFeed(tester);
    for (var i = 0; i < 8; i++) {
      await swipeUp(tester);
    }
    expect(bloc.state.currentEpisode?.id, 7);
    expect(shownPage(tester), 8.0);
    expect(pool.playingEpisodeId, isNull, reason: 'E7 never plays while locked');
    expect(find.text('Unlock Episode'), findsOneWidget);

    await swipeUp(tester);
    expect(shownPage(tester), 8.0, reason: 'the lock absorbs the fling');
    expect(bloc.state.currentEpisode?.id, 7);

    bloc.add(const PaywallUnlockRequested());
    await tester.pump();
    await settle(tester);
    expect(pool.playingEpisodeId, 7);

    await swipeUp(tester);
    expect(shownPage(tester), 9.0);
    expect(bloc.state.currentEpisode?.id, 8);
    expect(pool.playingEpisodeId, 8);

    await tearDownFeed(tester);
  });

  testWidgets('a failure mid-drag waits for the gesture to end', (
    tester,
  ) async {
    await pumpFeed(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(bloc.state.isScrollInProgress, isTrue);

    preloader.fail('ad_1');
    await tester.pump();
    expect(bloc.state.pendingAdRemovals, {'ad_1'});
    expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 AD E4 E5 E6 AD E7 E8');

    await gesture.up();
    await settle(tester);
    expect(bloc.state.isScrollInProgress, isFalse);
    expect(describeFeed(bloc.state.feedItems), 'E1 E2 E3 E4 E5 E6 AD E7 E8');
    expect(shownPage(tester), 0.0);

    await tearDownFeed(tester);
  });
}
