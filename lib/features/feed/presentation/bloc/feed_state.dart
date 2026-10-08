part of 'feed_bloc.dart';

enum AdLoadStatus { loading, loaded, failed }

class FeedState extends Equatable {
  final List<FeedItem> feedItems;
  final int currentPageIndex;
  final Map<String, AdLoadStatus> adStatuses;
  final bool isPaywallVisible;
  final bool isScrollLocked;
  final bool isEpisode7Unlocked;

  const FeedState({
    this.feedItems = const [],
    this.currentPageIndex = 0,
    this.adStatuses = const {},
    this.isPaywallVisible = false,
    this.isScrollLocked = false,
    this.isEpisode7Unlocked = false,
  });

  FeedState copyWith({
    List<FeedItem>? feedItems,
    int? currentPageIndex,
    Map<String, AdLoadStatus>? adStatuses,
    bool? isPaywallVisible,
    bool? isScrollLocked,
    bool? isEpisode7Unlocked,
  }) {
    return FeedState(
      feedItems: feedItems ?? this.feedItems,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      adStatuses: adStatuses ?? this.adStatuses,
      isPaywallVisible: isPaywallVisible ?? this.isPaywallVisible,
      isScrollLocked: isScrollLocked ?? this.isScrollLocked,
      isEpisode7Unlocked: isEpisode7Unlocked ?? this.isEpisode7Unlocked,
    );
  }

  @override
  List<Object?> get props => [
    feedItems,
    currentPageIndex,
    adStatuses,
    isPaywallVisible,
    isScrollLocked,
    isEpisode7Unlocked,
  ];
}
