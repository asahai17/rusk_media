part of 'feed_bloc.dart';

sealed class FeedEvent {
  const FeedEvent();
}

final class FeedInitialized extends FeedEvent {
  const FeedInitialized();
}

final class PageChanged extends FeedEvent {
  final int pageIndex;
  const PageChanged(this.pageIndex);
}

final class AdLoaded extends FeedEvent {
  final String adId;
  const AdLoaded(this.adId);
}

final class AdFailed extends FeedEvent {
  final String adId;
  const AdFailed(this.adId);
}

final class PaywallUnlockRequested extends FeedEvent {
  const PaywallUnlockRequested();
}

final class AdSlotAutoSkipped extends FeedEvent {
  final String adId;
  const AdSlotAutoSkipped(this.adId);
}
