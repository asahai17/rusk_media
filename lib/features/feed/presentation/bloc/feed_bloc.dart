import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/services/ad_preloader.dart';
import '../../data/services/episode_player_pool.dart';
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/feed_item.dart';
import '../../domain/policies/feed_composer.dart';
import '../../domain/usecases/get_feed_usecase.dart';

part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeedUseCase _getFeedUseCase;
  final AdPreloader _adPreloader;
  final EpisodePlayerPool _playerPool;
  StreamSubscription<String>? _adSuccessSub;
  StreamSubscription<String>? _adFailureSub;

  // Pure domain policy — testable without widget tree
  static const FeedComposer composer = FeedComposer(
    adEvery: AppConstants.adAfterEveryNEpisodes,
  );

  FeedBloc({
    required this._getFeedUseCase,
    required this._adPreloader,
    required this._playerPool,
  }) : super(const FeedState()) {
    on<FeedInitialized>(_onFeedInitialized);
    on<PageChanged>(_onPageChanged);
    on<AdLoaded>(_onAdLoaded);
    on<AdFailed>(_onAdFailed);
    on<ScrollStateChanged>(_onScrollStateChanged);
    on<PaywallUnlockRequested>(_onPaywallUnlockRequested);
    on<MuteToggled>(_onMuteToggled);
    on<PlaybackToggled>(_onPlaybackToggled);
    on<AppVisibilityChanged>(_onAppVisibilityChanged);

    _adSuccessSub = _adPreloader.successes.listen((slotId) {
      if (!isClosed) add(AdLoaded(slotId));
    });
    _adFailureSub = _adPreloader.failures.listen((slotId) {
      if (!isClosed) add(AdFailed(slotId));
    });
  }

  /// The pool pages read controllers from. Owned and disposed by this bloc.
  EpisodePlayerPool get playerPool => _playerPool;

  /// Playback is a pure function of state, so every state change is pushed
  /// to the pool from one place instead of from each handler.
  @override
  void onChange(Change<FeedState> change) {
    super.onChange(change);
    _syncPlayers(change.nextState);
  }

  void _onFeedInitialized(FeedInitialized event, Emitter<FeedState> emit) {
    final episodes = _getFeedUseCase.call().whereType<EpisodeFeedItem>();

    final feedItems = composer.compose(episodes.toList());

    emit(
      FeedState(
        feedItems: feedItems,
        lockedEpisodeId: AppConstants.paywallEpisodeId,
      ),
    );
    _preloadAdsAround(0, feedItems);
  }

  void _onPageChanged(PageChanged event, Emitter<FeedState> emit) {
    final items = state.feedItems;
    if (event.pageIndex < 0 || event.pageIndex >= items.length) return;

    emit(state.copyWith(currentPageIndex: event.pageIndex, isUserPaused: false));
    _preloadAdsAround(event.pageIndex, items);
    _applyPendingRemovals(emit);
  }

  void _onAdLoaded(AdLoaded event, Emitter<FeedState> emit) {
    final ad = _adPreloader.getLoadedAd(event.adId);
    if (ad == null || !_hasSlot(event.adId)) return;
    emit(state.copyWith(loadedAds: {...state.loadedAds, event.adId: ad}));
  }

  bool _hasSlot(String adId) =>
      state.feedItems.any((item) => item is AdFeedItem && item.id == adId);

  /// Marks the slot for removal. It leaves the feed in [_applyPendingRemovals]
  /// once the scroll is at rest; if the user is looking at it, FeedPage
  /// animates to the next episode first.
  void _onAdFailed(AdFailed event, Emitter<FeedState> emit) {
    if (!_hasSlot(event.adId) || state.pendingAdRemovals.contains(event.adId)) {
      return;
    }
    emit(
      state.copyWith(
        pendingAdRemovals: {...state.pendingAdRemovals, event.adId},
      ),
    );
    _applyPendingRemovals(emit);
  }

  void _onScrollStateChanged(
    ScrollStateChanged event,
    Emitter<FeedState> emit,
  ) {
    if (event.isScrolling == state.isScrollInProgress) return;
    emit(state.copyWith(isScrollInProgress: event.isScrolling));
    if (!event.isScrolling) _applyPendingRemovals(emit);
  }

  /// Drops every pending slot except the one on screen, and only while the
  /// scroll is at rest. Slots behind the current page shift the index up so
  /// the user keeps looking at the same content; FeedPage mirrors that shift
  /// onto the PageController in the same frame.
  void _applyPendingRemovals(Emitter<FeedState> emit) {
    if (state.isScrollInProgress || state.pendingAdRemovals.isEmpty) return;

    final current = state.currentPageIndex;
    final removable = <String>{};
    var shift = 0;
    for (var i = 0; i < state.feedItems.length; i++) {
      final item = state.feedItems[i];
      if (item is! AdFeedItem || !state.pendingAdRemovals.contains(item.id)) {
        continue;
      }
      if (i == current) continue;
      removable.add(item.id);
      if (i < current) shift++;
    }
    if (removable.isEmpty) return;

    final removed = {...state.removedAdSlots, ...removable};
    final feedItems = composer.compose(
      state.feedItems.whereType<EpisodeFeedItem>().toList(),
      removed: removed,
    );

    emit(
      state.copyWith(
        feedItems: feedItems,
        removedAdSlots: removed,
        pendingAdRemovals: state.pendingAdRemovals.difference(removable),
        currentPageIndex: current - shift,
      ),
    );
  }

  void _onPaywallUnlockRequested(
    PaywallUnlockRequested event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(isPaywallUnlocked: true));
  }

  void _onMuteToggled(MuteToggled event, Emitter<FeedState> emit) {
    emit(state.copyWith(isMuted: !state.isMuted));
  }

  void _onPlaybackToggled(PlaybackToggled event, Emitter<FeedState> emit) {
    emit(state.copyWith(isUserPaused: !state.isUserPaused));
  }

  void _onAppVisibilityChanged(
    AppVisibilityChanged event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(isAppInForeground: event.isForeground));
  }

  void _preloadAdsAround(int page, List<FeedItem> items) {
    _adPreloader.load(
      composer.slotsToLoad(
        items,
        current: page,
        ahead: AppConstants.adPreloadAhead,
      ),
    );
  }

  void _syncPlayers(FeedState s) {
    final current = s.currentEpisode;
    final active = current != null && !s.isEpisodeLocked(current.id)
        ? current.id
        : null;
    _playerPool.apply(
      warm: composer.episodesToWarm(
        s.feedItems,
        current: s.currentPageIndex,
        radius: AppConstants.videoPreloadRadius,
        isLocked: s.isEpisodeLocked,
      ),
      activeEpisodeId: active,
      shouldPlay: s.isAppInForeground && !s.isUserPaused,
      muted: s.isMuted,
    );
  }

  @override
  Future<void> close() {
    unawaited(_adSuccessSub?.cancel());
    unawaited(_adFailureSub?.cancel());
    _adPreloader.dispose();
    _playerPool.dispose();
    return super.close();
  }
}
