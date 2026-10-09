part of 'feed_bloc.dart';

class FeedState extends Equatable {
  /// Composed feed: episodes with ad slots interleaved, minus removed slots.
  final List<FeedItem> feedItems;
  final int currentPageIndex;

  /// Ads that finished loading, by slot id. A slot absent here is still
  /// loading (or has failed and is on its way out of [feedItems]). The
  /// preloader keeps the load state machine; this is the only copy the UI
  /// reads.
  final Map<String, NativeAd> loadedAds;

  /// Slot ids that failed and were dropped from [feedItems].
  final Set<String> removedAdSlots;

  /// Slot ids that failed but are still in [feedItems]: either the scroll is
  /// in progress, or the user is looking at the slot and FeedPage must move
  /// them off it first.
  final Set<String> pendingAdRemovals;

  /// True between ScrollStart and ScrollEnd; nothing is removed meanwhile.
  final bool isScrollInProgress;

  /// The one episode behind the paywall, or null when nothing is locked.
  final int? lockedEpisodeId;

  /// Once true, the locked episode plays and the forward-scroll lock lifts.
  final bool isPaywallUnlocked;

  /// Mute is shared across every episode in the session.
  final bool isMuted;

  /// False while the app is backgrounded; nothing plays in that state.
  final bool isAppInForeground;

  /// The user tapped to pause the current episode. Cleared on page change,
  /// deliberately not on backgrounding.
  final bool isUserPaused;

  const FeedState({
    this.feedItems = const [],
    this.currentPageIndex = 0,
    this.loadedAds = const {},
    this.removedAdSlots = const {},
    this.pendingAdRemovals = const {},
    this.isScrollInProgress = false,
    this.lockedEpisodeId,
    this.isPaywallUnlocked = false,
    this.isMuted = false,
    this.isAppInForeground = true,
    this.isUserPaused = false,
  });

  /// The single source of truth for "this episode is behind the paywall".
  bool isEpisodeLocked(int episodeId) =>
      !isPaywallUnlocked && episodeId == lockedEpisodeId;

  /// Page index of the locked episode, or null once unlocked.
  int? get lockedPageIndex {
    if (isPaywallUnlocked) return null;
    final index = feedItems.indexWhere(
      (item) => item is EpisodeFeedItem && item.episode.id == lockedEpisodeId,
    );
    return index >= 0 ? index : null;
  }

  FeedItem? get currentItem =>
      currentPageIndex >= 0 && currentPageIndex < feedItems.length
      ? feedItems[currentPageIndex]
      : null;

  /// The episode on the current page, or null on an ad page.
  EpisodeEntity? get currentEpisode {
    final item = currentItem;
    return item is EpisodeFeedItem ? item.episode : null;
  }

  /// True when the user is looking at a slot that has already failed.
  bool get isOnFailedAdSlot {
    final item = currentItem;
    return item is AdFeedItem && pendingAdRemovals.contains(item.id);
  }

  FeedState copyWith({
    List<FeedItem>? feedItems,
    int? currentPageIndex,
    Map<String, NativeAd>? loadedAds,
    Set<String>? removedAdSlots,
    Set<String>? pendingAdRemovals,
    bool? isScrollInProgress,
    int? lockedEpisodeId,
    bool? isPaywallUnlocked,
    bool? isMuted,
    bool? isAppInForeground,
    bool? isUserPaused,
  }) {
    return FeedState(
      feedItems: feedItems ?? this.feedItems,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      loadedAds: loadedAds ?? this.loadedAds,
      removedAdSlots: removedAdSlots ?? this.removedAdSlots,
      pendingAdRemovals: pendingAdRemovals ?? this.pendingAdRemovals,
      isScrollInProgress: isScrollInProgress ?? this.isScrollInProgress,
      lockedEpisodeId: lockedEpisodeId ?? this.lockedEpisodeId,
      isPaywallUnlocked: isPaywallUnlocked ?? this.isPaywallUnlocked,
      isMuted: isMuted ?? this.isMuted,
      isAppInForeground: isAppInForeground ?? this.isAppInForeground,
      isUserPaused: isUserPaused ?? this.isUserPaused,
    );
  }

  @override
  List<Object?> get props => [
    feedItems,
    currentPageIndex,
    loadedAds,
    removedAdSlots,
    pendingAdRemovals,
    isScrollInProgress,
    lockedEpisodeId,
    isPaywallUnlocked,
    isMuted,
    isAppInForeground,
    isUserPaused,
  ];
}
