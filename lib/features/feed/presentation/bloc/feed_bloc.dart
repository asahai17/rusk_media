import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/services/ad_preload_manager.dart';
import '../../domain/entities/feed_item.dart';
import '../../domain/policies/episode_paywall.dart';
import '../../domain/policies/feed_composer.dart';
import '../../domain/usecases/get_feed_usecase.dart';

part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeedUseCase _getFeedUseCase;
  final AdPreloadManager _adPreloadManager;
  StreamSubscription<String>? _adSuccessSub;
  StreamSubscription<String>? _adFailureSub;

  // Pure domain policies — testable without widget tree
  static const FeedComposer composer = FeedComposer();
  static const EpisodePaywall paywall = EpisodePaywall();

  FeedBloc({
    required GetFeedUseCase getFeedUseCase,
    required AdPreloadManager adPreloadManager,
  })  : _getFeedUseCase = getFeedUseCase, // ignore: prefer_initializing_formals
        _adPreloadManager = adPreloadManager, // ignore: prefer_initializing_formals
        super(const FeedState()) {
    on<FeedInitialized>(_onFeedInitialized);
    on<PageChanged>(_onPageChanged);
    on<AdLoaded>(_onAdLoaded);
    on<AdFailed>(_onAdFailed);
    on<AdSlotAutoSkipped>(_onAdSlotAutoSkipped);
    on<PaywallUnlockRequested>(_onPaywallUnlockRequested);

    _adSuccessSub = _adPreloadManager.successes.listen((slotId) {
      if (!isClosed) add(AdLoaded(slotId));
    });
    _adFailureSub = _adPreloadManager.failures.listen((slotId) {
      if (!isClosed) add(AdFailed(slotId));
    });
  }

  void _onFeedInitialized(
    FeedInitialized event,
    Emitter<FeedState> emit,
  ) {
    final episodes = _getFeedUseCase.call();

    // Use FeedComposer domain policy to interleave ads
    final feedItems = composer.compose(
      episodes.whereType<EpisodeFeedItem>().toList(),
      adUnitForSlot: AppConstants.adUnitForSlot,
    );

    final adStatuses = <String, AdLoadStatus>{};
    final adSlotIds = <String>[];
    for (final item in feedItems) {
      if (item is AdFeedItem) {
        adStatuses[item.id] = AdLoadStatus.loading;
        adSlotIds.add(item.id);
      }
    }

    emit(state.copyWith(
      feedItems: feedItems,
      adStatuses: adStatuses,
      currentPageIndex: 0,
      isPaywallVisible: false,
      isScrollLocked: false,
      isEpisode7Unlocked: false,
    ));

    _adPreloadManager.load(adSlotIds);
  }

  void _onPageChanged(PageChanged event, Emitter<FeedState> emit) {
    final items = state.feedItems;
    if (event.pageIndex >= items.length) return;

    // Use EpisodePaywall domain policy
    final shouldShow = paywall.shouldShowPaywall(
      items,
      event.pageIndex,
      unlocked: state.isEpisode7Unlocked,
    );

    emit(state.copyWith(
      currentPageIndex: event.pageIndex,
      isPaywallVisible: shouldShow,
      isScrollLocked: shouldShow,
    ));
  }

  void _onAdLoaded(AdLoaded event, Emitter<FeedState> emit) {
    final updated = Map<String, AdLoadStatus>.from(state.adStatuses);
    updated[event.adId] = AdLoadStatus.loaded;
    emit(state.copyWith(adStatuses: updated));
  }

  void _onAdFailed(AdFailed event, Emitter<FeedState> emit) {
    final updated = Map<String, AdLoadStatus>.from(state.adStatuses);
    updated[event.adId] = AdLoadStatus.failed;
    emit(state.copyWith(adStatuses: updated));
  }

  void _onAdSlotAutoSkipped(
    AdSlotAutoSkipped event,
    Emitter<FeedState> emit,
  ) {
    final updated = Map<String, AdLoadStatus>.from(state.adStatuses);
    updated[event.adId] = AdLoadStatus.failed;
    emit(state.copyWith(adStatuses: updated));
  }

  void _onPaywallUnlockRequested(
    PaywallUnlockRequested event,
    Emitter<FeedState> emit,
  ) {
    emit(state.copyWith(
      isPaywallVisible: false,
      isScrollLocked: false,
      isEpisode7Unlocked: true,
    ));
  }

  @override
  Future<void> close() {
    unawaited(_adSuccessSub?.cancel());
    unawaited(_adFailureSub?.cancel());
    _adPreloadManager.dispose();
    return super.close();
  }
}
