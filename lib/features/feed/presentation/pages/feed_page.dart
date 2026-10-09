import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/lifecycle/app_lifecycle_observer.dart';
import '../../domain/entities/feed_item.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/ad_slot_widget.dart';
import '../widgets/custom_scroll_physics.dart';
import '../widgets/episode_player_widget.dart';
import '../widgets/shimmer_skeleton.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final PageController _pageController;
  late final AppLifecycleObserver _lifecycleObserver;

  static const Duration _leaveSlotDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final bloc = context.read<FeedBloc>();
    _lifecycleObserver = AppLifecycleObserver(
      onPause: () => bloc.add(const AppVisibilityChanged(isForeground: false)),
      onResume: () => bloc.add(const AppVisibilityChanged(isForeground: true)),
    )..init();

    bloc.add(const FeedInitialized());
  }

  @override
  void dispose() {
    _lifecycleObserver.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    context.read<FeedBloc>().add(PageChanged(index));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final bloc = context.read<FeedBloc>();
    if (notification is ScrollStartNotification) {
      bloc.add(const ScrollStateChanged(isScrolling: true));
    } else if (notification is ScrollEndNotification) {
      bloc.add(const ScrollStateChanged(isScrolling: false));
    }
    return false;
  }

  /// Runs on every state change that can leave the PageController out of
  /// step with the state: a slot removal, a pending removal, scroll rest.
  void _syncPageController(FeedState state) {
    if (!_pageController.hasClients || state.isScrollInProgress) return;

    // A failed slot is on screen: move to the next episode; the bloc removes
    // the slot once this animation ends.
    if (state.isOnFailedAdSlot) {
      _pageController.animateToPage(
        state.currentPageIndex + 1,
        duration: _leaveSlotDuration,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // A slot before the current page was removed, so every later page shifted
    // up by one index. Jump (no animation) before the PageView rebuilds so
    // the viewport keeps showing the same content; content keys keep the
    // players alive.
    final shown = _pageController.page?.round();
    if (shown != state.currentPageIndex) {
      _pageController.jumpToPage(state.currentPageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: BlocConsumer<FeedBloc, FeedState>(
          listenWhen: (prev, curr) =>
              prev.feedItems.length != curr.feedItems.length ||
              prev.pendingAdRemovals != curr.pendingAdRemovals ||
              prev.isScrollInProgress != curr.isScrollInProgress ||
              prev.currentPageIndex != curr.currentPageIndex,
          listener: (_, state) => _syncPageController(state),
          // Only what the PageView itself lays out. Mute and pause are read
          // by each page through context.select.
          buildWhen: (prev, curr) =>
              prev.feedItems != curr.feedItems ||
              prev.currentPageIndex != curr.currentPageIndex ||
              prev.isPaywallUnlocked != curr.isPaywallUnlocked ||
              prev.loadedAds != curr.loadedAds,
          builder: (context, state) {
            if (state.feedItems.isEmpty) {
              return const ShimmerSkeleton();
            }

            final bloc = context.read<FeedBloc>();
            final items = state.feedItems;

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              // Builds one page either side of the viewport so the
              // neighbour's video surface is mounted before the user swipes
              // to it. The player itself is already warm: the pool does not
              // depend on the page being built.
              allowImplicitScrolling: true,
              physics: ReelScrollPhysics(
                lockedPage: () => bloc.state.lockedPageIndex,
              ),
              onPageChanged: _onPageChanged,
              itemCount: items.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final idx = items.indexWhere(
                  (item) => _keyFor(item) == key.value,
                );
                return idx >= 0 ? idx : null;
              },
              itemBuilder: (context, index) {
                final item = items[index];

                return switch (item) {
                  EpisodeFeedItem(:final episode) => EpisodePlayerWidget(
                    key: ValueKey(_keyFor(item)),
                    episode: episode,
                    isActive: index == state.currentPageIndex,
                    isLocked: state.isEpisodeLocked(episode.id),
                    pool: bloc.playerPool,
                  ),
                  AdFeedItem(:final id) => AdSlotWidget(
                    key: ValueKey(_keyFor(item)),
                    ad: state.loadedAds[id],
                  ),
                };
              },
            );
          },
        ),
      ),
    );
  }

  static String _keyFor(FeedItem item) => switch (item) {
    EpisodeFeedItem(:final episode) => 'ep_${episode.id}',
    AdFeedItem(:final id) => 'ad_$id',
  };
}
