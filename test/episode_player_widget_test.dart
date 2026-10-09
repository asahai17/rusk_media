import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/data/services/episode_player_pool.dart';
import 'package:md_television/features/feed/domain/usecases/get_feed_usecase.dart';
import 'package:md_television/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:md_television/features/feed/presentation/widgets/episode_player_widget.dart';
import 'package:md_television/features/feed/presentation/widgets/episode_video_surface.dart';
import 'package:md_television/features/feed/presentation/widgets/shimmer_skeleton.dart';
import 'package:video_player/video_player.dart';

import 'fakes/fake_feed_dependencies.dart';
import 'fakes/fake_video_player_platform.dart';

void main() {
  late FakeVideoPlayerPlatform platform;
  late EpisodePlayerPool pool;
  late FeedBloc bloc;

  setUp(() {
    platform = FakeVideoPlayerPlatform.install();
  });

  /// Mounts E1 as the active page and starts the feed, so the bloc drives the
  /// pool exactly as it does in the app. The bloc and pool are built here,
  /// inside the fake-async zone, so their stream work is pumped with the tree.
  Future<void> pumpPlayer(WidgetTester tester) async {
    pool = EpisodePlayerPool(setWakelock: (_) async {});
    bloc = FeedBloc(
      getFeedUseCase: GetFeedUseCase(FakeFeedRepository()),
      adPreloader: FakeAdPreloader(),
      playerPool: pool,
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<FeedBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(
            body: EpisodePlayerWidget(
              episode: episode(1),
              isActive: true,
              isLocked: false,
              pool: pool,
            ),
          ),
        ),
      ),
    );
    bloc.add(const FeedInitialized());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Unmounts first so no widget touches a controller the pool is disposing,
  /// then releases the players so their position timers stop inside the
  /// fake-async zone. The bloc itself is closed by the tear-down.
  Future<void> tearDownPlayer(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    pool.dispose();
    await tester.pump();
  }

  testWidgets('shows the shimmer until the pool is ready, then the video', (
    tester,
  ) async {
    platform.createGate = Completer<void>();
    await pumpPlayer(tester);
    expect(find.byType(ShimmerSkeleton), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);

    platform.createGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ShimmerSkeleton), findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);

    await tearDownPlayer(tester);
  });

  testWidgets('an init failure shows a retry card instead of the shimmer', (
    tester,
  ) async {
    platform.failNextCreate = true;
    await pumpPlayer(tester);
    expect(find.text("Couldn't load this episode"), findsOneWidget);
    expect(find.byType(ShimmerSkeleton), findsNothing);

    await tester.tap(find.text('Retry'));
    // The gesture layer's double-tap recogniser holds every tap for 300 ms.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Couldn't load this episode"), findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(pool.playingEpisodeId, 1);

    await tearDownPlayer(tester);
  });

  testWidgets('the buffering ring follows the controller value', (
    tester,
  ) async {
    await pumpPlayer(tester);
    final controller = pool.controllerFor(1)!;
    expect(find.byKey(EpisodeVideoSurface.bufferingKey), findsNothing);

    controller.value = controller.value.copyWith(isBuffering: true);
    await tester.pump();
    expect(find.byKey(EpisodeVideoSurface.bufferingKey), findsOneWidget);

    controller.value = controller.value.copyWith(isBuffering: false);
    await tester.pump();
    expect(find.byKey(EpisodeVideoSurface.bufferingKey), findsNothing);

    await tearDownPlayer(tester);
  });

  testWidgets('a tap pauses through the bloc and shows the pause glyph', (
    tester,
  ) async {
    await pumpPlayer(tester);
    expect(pool.playingEpisodeId, 1);

    await tester.tap(find.byType(EpisodePlayerWidget));
    // Single tap resolves after the double-tap window.
    await tester.pump(const Duration(milliseconds: 400));
    expect(bloc.state.isUserPaused, isTrue);
    expect(pool.playingEpisodeId, isNull);
    await tester.pump(const Duration(milliseconds: 100)); // glyph fades in
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tearDownPlayer(tester);
  });

  testWidgets('no Material progress indicator is ever shown', (tester) async {
    platform.createGate = Completer<void>();
    await pumpPlayer(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    platform.createGate!.complete();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tearDownPlayer(tester);
  });
}
