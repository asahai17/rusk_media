import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/lifecycle/app_lifecycle_observer.dart';
import '../../domain/entities/feed_item.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/ad_slot_widget.dart';
import '../widgets/custom_scroll_physics.dart';
import '../widgets/episode_player_widget.dart';
import '../widgets/onboarding_sheet.dart';
import '../widgets/shimmer_skeleton.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late PageController _pageController;
  late AppLifecycleObserver _lifecycleObserver;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _lifecycleObserver = AppLifecycleObserver(
      onPause: () {},
      onResume: () {},
    );
    _lifecycleObserver.init();

    context.read<FeedBloc>().add(const FeedInitialized());

    // Check if first launch — show onboarding
    OnboardingSheet.shouldShow().then((show) {
      if (show && mounted) setState(() => _showOnboarding = true);
    });
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

  void _dismissOnboarding() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main feed
          BlocBuilder<FeedBloc, FeedState>(
            buildWhen: (prev, curr) =>
                prev.feedItems != curr.feedItems ||
                prev.currentPageIndex != curr.currentPageIndex ||
                prev.isScrollLocked != curr.isScrollLocked ||
                prev.isPaywallVisible != curr.isPaywallVisible ||
                prev.isEpisode7Unlocked != curr.isEpisode7Unlocked ||
                prev.adStatuses != curr.adStatuses,
            builder: (context, state) {
              if (state.feedItems.isEmpty) {
                return const ShimmerSkeleton();
              }

              final items = state.feedItems;
              final lockedPage =
                  FeedBloc.paywall.lockedPage(items) ?? items.length;

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: ReelScrollPhysics(
                  isLocked: state.isScrollLocked,
                  lockedPageIndex: lockedPage,
                ),
                onPageChanged: _onPageChanged,
                itemCount: items.length,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) {
                    final idx = items.indexWhere((item) {
                      if (item is EpisodeFeedItem) {
                        return 'ep_${item.episode.id}' == key.value;
                      }
                      if (item is AdFeedItem) {
                        return 'ad_${item.id}' == key.value;
                      }
                      return false;
                    });
                    return idx >= 0 ? idx : null;
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  // Hold playback while onboarding is visible
                  final isActive =
                      state.currentPageIndex == index && !_showOnboarding;

                  return switch (item) {
                    EpisodeFeedItem(:final episode) => EpisodePlayerWidget(
                        key: ValueKey('ep_${episode.id}'),
                        episode: episode,
                        isActive: isActive,
                        isPaywallActive: state.isPaywallVisible &&
                            state.currentPageIndex == index &&
                            FeedBloc.paywall.isLockedEpisode(episode.id),
                        isPaywallUnlocked: state.isEpisode7Unlocked,
                      ),
                    AdFeedItem(:final id, :final adUnitId) => AdSlotWidget(
                        key: ValueKey('ad_$id'),
                        adId: id,
                        adUnitId: adUnitId,
                        adLoadStatus:
                            state.adStatuses[id] ?? AdLoadStatus.loading,
                        pageController: _pageController,
                        pageIndex: index,
                      ),
                  };
                },
              );
            },
          ),

          // Onboarding overlay — shows once on first launch
          if (_showOnboarding)
            OnboardingSheet(onDismiss: _dismissOnboarding),
        ],
      ),
    );
  }
}
